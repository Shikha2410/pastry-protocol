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
      Registry.start_link(keys: :unique, name: :node_registry)
      PastrySimulator.Implementation.pastry(numNodes,numRequests)
    end
end