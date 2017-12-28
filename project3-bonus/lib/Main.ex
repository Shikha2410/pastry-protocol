defmodule PastrySimulator.Main do
    def main(args) do
      args |> parse_args |> delegate
    end

    defp parse_args(args) do
      {_,parameters,_} = OptionParser.parse(args)
      parameters
    end
    
    def delegate([]) do
      IO.puts "No arguments given"
    end

    def delegate(parameters) do
      numNodes = String.to_integer(Enum.at(parameters,0))
      numRequests = String.to_integer(Enum.at(parameters,1))
      nodes_to_fail = Enum.at(parameters,2)
      nodes_to_fail = if nodes_to_fail == nil do
        IO.puts "Failing 5% of total nodes in the Pastry network."
        round(numNodes/20)
      else
        String.to_integer(nodes_to_fail)
      end 
      Registry.start_link(keys: :unique, name: :node_registry)
      PastrySimulator.Implementation.pastry(numNodes,numRequests,nodes_to_fail)
    end
end