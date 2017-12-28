defmodule PastrySimulator.Pastry_Default_Actor do
    use GenServer
    require Logger

    @node_registry_name :node_registry

    def pastryInit(node_id,nearbyNode) do
        GenServer.start_link(__MODULE__, [node_id,nearbyNode], name: via_tuple(node_id))
        node_id
    end

    # registry lookup handler
    defp via_tuple(node_id), do: {:via, Registry, {@node_registry_name, node_id}}

    def whereis(node_id) do
        case Registry.lookup(@node_registry_name, node_id) do
        [{pid, _}] -> pid
        [] -> nil
        end
    end

    def init([node_id,nearbyNode]) do

        {smallerleafset,greaterleafset,routingtable,neighbourhoodset} = if nearbyNode==-1, do: {[],[],createEmptyRT(%{},7),[]}, else: setState(node_id,nearbyNode)
        send(:global.whereis_name(:mainapp),{:initiated})
        route(node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset)  
        {:ok, node_id}
    end

    def setState(node_id,nearbyNode) do
        send(PastrySimulator.Pastry_Default_Actor.whereis(nearbyNode),{:join,0,%{},node_id})
        neighbourhoodset = receive do
                                {:yourNeighbourhoodSet,set} -> if length(set) < 8 do
                                                                    set ++ [nearbyNode]
                                                               else
                                                                    List.delete_at(set,0) ++ [nearbyNode]
                                                               end
                           end
        {smallerleafset,greaterleafset} = receive do
                                            {:yourLeafSet,smallerset,greaterset, closestleafnode} -> if node_id > closestleafnode do
                                                                                                        if length(smallerset)<4 do
                                                                                                            {smallerset ++ [closestleafnode],greaterset}
                                                                                                        else
                                                                                                            {List.replace_at(smallerset,0,closestleafnode),greaterset}
                                                                                                        end
                                                                                                     else
                                                                                                        if length(greaterset)<4 do
                                                                                                            {smallerset,greaterset ++ [closestleafnode]}
                                                                                                        else
                                                                                                            {smallerset,List.replace_at(greaterset,3,closestleafnode)}
                                                                                                        end
                                                                                                     end
                                          end
        routingtable = receive do
                            {:yourRoutingTableReference,routingTablesMap} -> list = get_routing_table_candidatesList(routingTablesMap)
                                                                             loop(%{},list,node_id,7)
                       end
        broadcast_toList = Enum.uniq(smallerleafset ++ greaterleafset ++ convertRTintoList([],routingtable,7) ++ neighbourhoodset)
        Enum.each(broadcast_toList,fn(x) -> send(PastrySimulator.Pastry_Default_Actor.whereis(x),{:updateState,node_id}) end)
        {Enum.sort(smallerleafset),Enum.sort(greaterleafset),routingtable,neighbourhoodset}
    end

    def loop(routingTable,_,_,-1), do: routingTable
    
    def loop(routingTable,nodelist,nodeId,num_of_rows) do
        nth_list = Enum.filter(nodelist,fn(x) -> String.slice(x,0,num_of_rows)==String.slice(nodeId,0,num_of_rows) end)
        nth_row = loopColumns({},Enum.sort(nth_list),num_of_rows,0)
        routingTable = Map.put(routingTable,num_of_rows,nth_row)
        nodelist = nodelist -- nth_list
        loop(routingTable,nodelist,nodeId,num_of_rows-1)
    end

    def loopColumns(nth_row,_,_,4), do: nth_row

    def loopColumns(nth_row,nth_list,differing_digit,counter) do 
        nth_row = Tuple.append(nth_row,Enum.find(nth_list,fn(x) -> String.to_integer(String.at(x,differing_digit))==counter end))
        loopColumns(nth_row,nth_list,differing_digit,counter+1)
    end

    def get_routing_table_candidatesList(routingTablesMap) do
        totrows = Enum.max(Map.keys(routingTablesMap))
        run_on_all_rts([],routingTablesMap,totrows)
    end

    def run_on_all_rts(poplist,_,-1), do: poplist

    def run_on_all_rts(poplist,routingTablesMap,totrows) do
        routingTable = Map.fetch!(routingTablesMap,totrows)
        poplist = poplist ++ convertRTintoList([],routingTable,7)
        run_on_all_rts(poplist,routingTablesMap,totrows-1)
    end

    def createEmptyRT(routingTable,-1), do: routingTable

    def createEmptyRT(routingTable,index) do
        routingTable=Map.put(routingTable,index,{nil,nil,nil,nil})
        createEmptyRT(routingTable,index-1)
    end

    def convertRTintoList(list,_,-1), do: Enum.uniq(list) -- [nil]

    def convertRTintoList(list,routingTable,map_key) do
        list = list ++ Tuple.to_list(Map.fetch!(routingTable,map_key))
        convertRTintoList(list,routingTable,map_key-1)
    end

    def route(node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset)  do
        {smallerleafset,greaterleafset,routingtable,neighbourhoodset} = receive do
            {:join,index,routingTablesMap,key} -> if index == 0, do: send(PastrySimulator.Pastry_Default_Actor.whereis(key),{:yourNeighbourhoodSet,neighbourhoodset})
                                                  routingTablesMap = Map.put(routingTablesMap,index,routingtable)
                                                  join_helper(node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset,index,routingTablesMap,key)
                                                  {smallerleafset,greaterleafset,routingtable,neighbourhoodset}
            {:updateState,newnode_id} -> updateState_helper(newnode_id,node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset)
            {:startrequesting,numRequests} -> Task.start fn -> start_pastry(node_id,numRequests) end
                                              {smallerleafset,greaterleafset,routingtable,neighbourhoodset}
            {:routemsg,hopcount,key} -> route_helper(node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset,hopcount,key)
                                        {smallerleafset,greaterleafset,routingtable,neighbourhoodset}
        end
        route(node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset)
    end

    def updateState_helper(newnode_id,currnode_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset) do
        smallerleafset = if smallerleafset==[], do: [currnode_id], else: smallerleafset
        greaterleafset = if greaterleafset==[], do: [currnode_id], else: greaterleafset
        {smallerleafset,greaterleafset,routingtable} = if(newnode_id > List.first(smallerleafset) && newnode_id < List.last(greaterleafset)) do
            smallerleafset = smallerleafset -- [currnode_id]
            greaterleafset = greaterleafset -- [currnode_id]
            if newnode_id < currnode_id do
                if length(smallerleafset)<4 do
                    {smallerleafset ++ [newnode_id],greaterleafset,routingtable}
                else
                    {List.replace_at(smallerleafset,0,newnode_id),greaterleafset,routingtable}
                end
            else
                if length(greaterleafset)<4 do
                    {smallerleafset,greaterleafset ++ [newnode_id],routingtable}
                else
                    {smallerleafset,List.replace_at(greaterleafset,3,newnode_id),routingtable}
                end
            end
        else
            smallerleafset = smallerleafset -- [currnode_id]
            greaterleafset = greaterleafset -- [currnode_id]
            length_of_common_prefix = find_common_prefix_length(String.codepoints(newnode_id),String.codepoints(currnode_id),0)
            index = String.to_integer(String.at(newnode_id,length_of_common_prefix))
            get_tuple = Map.fetch!(routingtable, length_of_common_prefix)
            get_tuple = if(elem(get_tuple,index) == nil) do
                Tuple.insert_at(Tuple.delete_at(get_tuple, index), index, newnode_id)
            else
                get_tuple
            end
            routingtable = Map.put(routingtable, length_of_common_prefix, get_tuple)
            {smallerleafset,greaterleafset,routingtable}
        end
        # Implement logic for neighbourhood set!
        {Enum.sort(smallerleafset),Enum.sort(greaterleafset),routingtable,neighbourhoodset}
    end

    def join_helper(node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset,index,routingTablesMap,key) do
        if (key < node_id && smallerleafset == []) || (key > node_id && greaterleafset == []) || (key == node_id) do
            send(PastrySimulator.Pastry_Default_Actor.whereis(key),{:yourLeafSet,smallerleafset,greaterleafset, node_id})
            send(PastrySimulator.Pastry_Default_Actor.whereis(key),{:yourRoutingTableReference,routingTablesMap})
        else
            smallerleafset = if smallerleafset==[], do: [node_id], else: smallerleafset
            greaterleafset = if greaterleafset==[], do: [node_id], else: greaterleafset
            if(key >= List.first(smallerleafset) && key <= List.last(greaterleafset)) do
                closest_leaf =  if(key > node_id) do
                                    find_closest_leaf([node_id] ++ greaterleafset,String.to_integer(key))
                                else
                                    find_closest_leaf(smallerleafset ++ [node_id],String.to_integer(key))
                                end
                if(closest_leaf == node_id) do
                    send(PastrySimulator.Pastry_Default_Actor.whereis(key),{:yourLeafSet,smallerleafset -- [node_id],greaterleafset -- [node_id],node_id})
                    send(PastrySimulator.Pastry_Default_Actor.whereis(key),{:yourRoutingTableReference,routingTablesMap})
                else
                    send(PastrySimulator.Pastry_Default_Actor.whereis(closest_leaf),{:join,index+1,routingTablesMap,key})
                end
            else
                common_prefix_length = find_common_prefix_length(String.codepoints(key),String.codepoints(node_id),0)
                at_index = String.to_integer(String.at(key,common_prefix_length))
                prefix_tuple = routingtable[common_prefix_length]
                node_to_fwd = elem(prefix_tuple,at_index)
                node_to_fwd = if(node_to_fwd != nil) do
                                node_to_fwd
                              else
                                find_closest_leaf(Tuple.to_list(prefix_tuple) ++ smallerleafset ++ greaterleafset ++ neighbourhoodset -- [node_id],String.to_integer(key))
                              end
                send(PastrySimulator.Pastry_Default_Actor.whereis(node_to_fwd),{:join,index+1,routingTablesMap,key})
            end
        end
    end

    def route_helper(node_id,smallerleafset,greaterleafset,routingtable,neighbourhoodset,hopcount,key) do
        if (key < node_id && smallerleafset == []) || (key > node_id && greaterleafset == []) || (key == node_id) do
            deliver(hopcount,key,node_id)
        else
            smallerleafset = if smallerleafset==[], do: [node_id], else: smallerleafset
            greaterleafset = if greaterleafset==[], do: [node_id], else: greaterleafset
            if(key >= List.first(smallerleafset) && key <= List.last(greaterleafset)) do
                closest_leaf =  if(key > node_id) do
                                    find_closest_leaf([node_id] ++ greaterleafset,String.to_integer(key))
                                else
                                    find_closest_leaf(smallerleafset ++ [node_id],String.to_integer(key))
                                end
                if(closest_leaf == node_id) do
                    deliver(hopcount,key,node_id)
                else
                    node_to_send = PastrySimulator.Pastry_Default_Actor.whereis(closest_leaf)
                    node_to_send = if(node_to_send != nil) do
                        node_to_send
                    else
                        get_next_closest_node_alive(smallerleafset ++ [node_id] ++ greaterleafset,String.to_integer(key))
                    end
                    if(node_to_send == -1 || node_to_send == PastrySimulator.Pastry_Default_Actor.whereis(node_id)) do
                        deliver(hopcount,key,node_id)
                    else
                        send(node_to_send,{:routemsg,hopcount+1,key})
                    end
                end
            else
                common_prefix_length = find_common_prefix_length(String.codepoints(key),String.codepoints(node_id),0)
                index = String.to_integer(String.at(key,common_prefix_length))
                prefix_tuple = routingtable[common_prefix_length]
                node_to_fwd = elem(prefix_tuple,index)
                node_to_fwd = if(node_to_fwd != nil) do
                                node_to_fwd
                              else
                                find_closest_leaf(Tuple.to_list(prefix_tuple) ++ smallerleafset ++ greaterleafset ++ neighbourhoodset -- [node_id],String.to_integer(key))
                              end
                node_to_send_rare = PastrySimulator.Pastry_Default_Actor.whereis(node_to_fwd)
                node_to_send_rare = if(node_to_send_rare != nil) do
                    node_to_send_rare
                else
                    get_next_closest_node_alive(Tuple.to_list(prefix_tuple) ++ smallerleafset ++ greaterleafset -- [node_id],String.to_integer(key))
                end
                if(node_to_send_rare == -1 || node_to_send_rare == PastrySimulator.Pastry_Default_Actor.whereis(node_id)) do
                    deliver(hopcount,key,node_id)
                else
                    send(node_to_send_rare,{:routemsg,hopcount+1,key})
                end
            end
        end
    end

    def get_next_closest_node_alive([],_), do: -1

    def get_next_closest_node_alive(list,key) do
        list = Enum.reject(list, &is_nil(&1))
        alive_node = Enum.min_by(list, &abs(String.to_integer(&1) - key))
        if(PastrySimulator.Pastry_Default_Actor.whereis(alive_node)==nil) do
            get_next_closest_node_alive(list -- [alive_node],key)
        else
            PastrySimulator.Pastry_Default_Actor.whereis(alive_node)
        end
    end

    def find_closest_leaf(list,key) do
        list = Enum.reject(list, &is_nil(&1))
        Enum.min_by(list, &abs(String.to_integer(&1) - key))
    end

    def find_common_prefix_length([head1 | tail1],[head2 | tail2],prefix_length) do
        if head1==head2, do: find_common_prefix_length(tail1,tail2,prefix_length+1), else: prefix_length
    end

    def deliver(hopcount,key,node_id) do
        send(:global.whereis_name(:mainproc),{:deliver,hopcount,key,node_id})
    end

    def start_pastry(_,0), do: nil

    def start_pastry(parent,numRequests) do
        # Sleep for number of milliseconds
        Process.sleep(1000)
        key = randomizer(8)
        send(PastrySimulator.Pastry_Default_Actor.whereis(parent),{:routemsg,0,key})
        start_pastry(parent,numRequests-1)
    end

    def randomizer(length) do
       numbers = "0123"
       lists =numbers |> String.split("", trim: true)
       do_randomizer(length, lists)
    end

    defp get_range(length) when length > 1, do: (1..length)
    defp get_range(_), do: [1]

    defp do_randomizer(length, lists) do
       get_range(length)
       |> Enum.reduce([], fn(_, acc) -> [Enum.random(lists) | acc] end)
       |> Enum.join("")
    end
end