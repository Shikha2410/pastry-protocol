# COP5615 : DISTRIBUTED SYSTEMS - PASTRY PROTOCOL
The goal of this project is to implement in Elixir using the actor model the pastry protocol and a simple object access service to prove its usefulness.

Authors

Shikha Mehta (UF ID 4851 9256)
Aniketh Sukhtankar (UF ID 7819 9584)


CONTENTS OF THIS FILE 
---------------------
   
 * Required Answers  
 * Introduction
 * Pre-requisites
 * Program inputs
 * Running project3.tgz
 * Running project3-bonus.tgz


REQUIRED ANSWERS
----------------
* Team members

  Shikha Mehta (UF ID 4851 9256) shikha.mehta@ufl.edu
  Aniketh Sukhtankar (UF ID 7819 9584) asukhtankar@ufl.edu

* What is working

  - We successfully implemented Pastry APIs for network join and routing as described in the Pastry paper.
  - Each of the nodes (specified by numNodes parameter) are getting added to the network, and begin requesting/second (upto numRequests/node). Every request is getting routed to a node that is numerically closest to the given key, as expected.
  - We are displaying status messages for each successful node join and message delivery, along with the number of hops each message took.
  - The final output - i.e. average number of hops that have to be traversed to deliver a message - is computed and printed to console before the program terminates.
  - For the bonus part of the project, we have modeled failure of specified number of nodes, and discussed system resilience in our bonus-report.
  - In conclusion, the goals of this project have been successfully met along with the bonus implementation.

* What is the largest network you managed to deal with

We managed to create a Pastry network of 65536 nodes.
Values larger than the above lie beyond the valid range of node IDs randomly generated by our application.

INTRODUCTION
------------
The project folder contains 2 sub-folders:

* project3: Contains the files related to the Pastry network project.
          - Main.ex
          - Implementation.ex
	  - Pastry_Default_Actor.ex

* project3-bonus: Contains the files related to the bonus part of the project.
	        - Main.ex
        	- Implementation.ex
	 	- Pastry_Default_Actor.ex
         	- bonus-report.pdf

PRE-REQUISITES
------------
The following need to be installed to run the project:
* Elixir
* Erlang

PROGRAM INPUTS
------------
* PASTRY
  - the number of nodes (should be < 65536, which is the limit of our random node ID generator)
  - the number of requests each node must perform

* BONUS
  - the number of nodes (should be < 65536, which is the limit of our random node ID generator)
  - the number of requests each node must perform
  - the number of nodes to kill (takes 5% of numNodes by default)

RUNNING project3.tgz
------------------------------
 Go to the folder 'project3' using command line tool and type: escript project3 numNodes numRequests
 This will start up the application and create a Pastry network of numNodes. When all peers created in the network perform numRequests each, the program can exit.

RUNNING project3-bonus.tgz
------------------------------
 Go to the folder 'project3-bonus' using command line tool and type: escript project3 numNodes numRequests numNodesToFail
 This will start up the application and create a Pastry network of numNodes. When all peers created in the network perform numRequests each, the program can exit. numNodesToFail specifies the number of node failures to simulate while the app is running.
