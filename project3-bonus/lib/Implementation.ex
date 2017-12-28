defmodule PastrySimulator.Implementation do
    def pastry(numNodes,numRequests,nodes_to_fail) do
        map_set = MapSet.new
        map_set = generate_unique_node_ids(numNodes,map_set)
        nodelist = MapSet.to_list(map_set)      
        
        :global.register_name(:mainapp,self())
        [head | _] = nodelist
        pid = spawn(fn -> PastrySimulator.Pastry_Default_Actor.pastryInit(head,-1) end)
        Process.monitor(pid)
        receive do
            {:initiated} -> IO.puts "Pastry node #{head} created!"
        end
        pastry_initiate(nodelist -- [head],head,numRequests) 
        
        stopping_threshold = numNodes*numRequests - nodes_to_fail*numRequests
        parent = self()
        pastryDeliver_task = Task.async(fn -> pastryDeliver(parent,stopping_threshold,0) end)
        :global.register_name(:mainproc,pastryDeliver_task.pid)

        pastry_failure(nodelist,numNodes,nodes_to_fail,0)
        
        start_time = System.system_time(:millisecond)
        pastry_starter(nodelist,numRequests)
        Task.await(pastryDeliver_task, :infinity)
        time_diff = System.system_time(:millisecond) - start_time
        IO.puts "Time taken for all messages to be delivered: #{time_diff} milliseconds"

        receive do
            {:totalhops,numHops} -> avghops = numHops/stopping_threshold
                                    IO.puts "Average number of hops (rounded up to the nearest integer) is #{round(Float.ceil(avghops))}"
        end
    end

    def pastry_failure(nodelist,numNodes,nodes_to_fail,nodes_failed) do
        if nodes_failed < nodes_to_fail do
            index_fail_node = :rand.uniform(length(nodelist))-1
            fail_node = Enum.at(nodelist,index_fail_node)
            fail_node_id = PastrySimulator.Pastry_Default_Actor.whereis(fail_node)
            if fail_node_id != nil do
                Process.exit(fail_node_id,:kill)
                pastry_failure(nodelist,numNodes,nodes_to_fail,nodes_failed+1)
            else
                pastry_failure(nodelist,numNodes,nodes_to_fail,nodes_failed)
            end
        end
    end

    def fail_helper(nodes_to_fail) do
        receive do
          {:DOWN, _, :process, _, :killed} -> IO.puts "#{nodes_to_fail} nodes killed"
        end
    end

    def generate_unique_node_ids(numNodes,map_set) do
       if(MapSet.size(map_set) < numNodes) do
           map_set = MapSet.put(map_set,randomizer(8))
           generate_unique_node_ids(numNodes,map_set)
       else
           map_set
       end
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

    def pastry_initiate([],_,_), do: nil

    def pastry_initiate([head | tail],nearbyNode,numRequests) do
        pid = spawn(fn -> PastrySimulator.Pastry_Default_Actor.pastryInit(head,nearbyNode) end)
        Process.monitor(pid)
        receive do
            {:initiated} -> IO.puts "Pastry node #{head} created!"
        end
        pastry_initiate(tail,head,numRequests)
    end

    def pastry_starter([],_), do: nil

    def pastry_starter([head | tail],numRequests) do
        pastry_node = PastrySimulator.Pastry_Default_Actor.whereis(head)
        if(pastry_node != nil) do
            send(PastrySimulator.Pastry_Default_Actor.whereis(head),{:startrequesting,numRequests})
        end
        pastry_starter(tail,numRequests)
    end

    def pastryDeliver(parent,0,numHops) do
        send(parent,{:totalhops,numHops})
    end

    def pastryDeliver(parent,stopping_threshold,numHops) do
        receive do
            {:deliver,hops,key,node_id} -> IO.puts "Message with key #{key} was delivered at #{node_id} in #{hops} hops." 
                                             pastryDeliver(parent,stopping_threshold-1,numHops+hops)
        end
    end
end