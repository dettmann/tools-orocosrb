require 'forwardable'
require 'utilrb/event_loop'

# Module for asynchronously accessing OROCOS Tasks by deferring blocking calls
# to the thread pool {Orocos::Async.thread_pool}. The results of the calls are later on
# processed by the event loop {Orocos::Async.event_loop} to synchronize them with the main
# thread. Therefore to use the asynchronous API the event loop must be running by either
# calling {Async.exec} or {Async.step}.
#
# All ruby OROCOS objects are wrapped by asynchronous counter parts:
#  Orocos::NameService => Orocos::Async::NameService
#  Orocos::TaskContext => Orocos::Async::TaskContext
#  Orocos::OutputPort => Orocos::Async::OutputPort
#
# These wrappers can be created without the need for a running remote Orocos
# Task:
#   task = Orocos::Async.name_service.get "task_name"
#   port = task.port "port_name"
#   reader = port.reader
#
# The asynchronous object usually forwards all calls to its synchronous
# counter part. But if a code block is given the block is used as callback
# and the original call is deferred to a thread pool:
#   # synchronous blocking calls
#   puts task.state
#   puts reader.read
#
#   # asynchronous non blocking calls
#   task.state do |state|
#       puts state
#   end
#   reader.read do |value|
#       puts value 
#   end
#
# If a method call needs the remote Orocos Task which is currently not reachable
# the method call will be suppressed and nil is returned. This behaviour can be changed
# by setting [TaskContext#raise=] to true.
#
# Most of the asynchronous object have a way to register callbacks for certain
# events. Most of these events are generated by polling but when ever it is
# possible they are generated by blocking function calls, called from a worker
# thread. Therefore if too many events are monitored the thread pool might run
# short on worker threads.
#
#   # these events are generated by polling
#   task.on_connect do 
#       puts "connected"
#   end
#   task.on_disconnect do 
#       puts "disconnected"
#   end
#   task.on_reconnect do 
#       puts "reconnected"
#   end
#
#   # this will block a worker thread until
#   # the state changed
#   task.on_state_change do |state|
#       puts state
#   end
#
#   # this will block a worker thread until
#   # new data are available
#   port.on_new_data do |data|
#       puts data
#   end
# 
# The polling frequency can be changed by setting the period attribute of each
# asynchronous object.
#
module Orocos::Async
    class << self
        extend ::Forwardable

        # @!method exec(period=0.05,&block)
        #   (see Utilrb::EventLoop#exec)
        #
        # @!method step(time=Time.now,&block)
        #   (see Utilrb::EventLoop#step)
        #
        # @!method wait_for(&block)
        #   (see Utilrb::EventLoop#wait_for)
        def_delegators :event_loop,:exec,:wait_for,:step,:steps,:clear,:stop,:every,:once
    end

    # Returns the event loop used by {Orocos::Async}
    #
    # @return [Utilrb::EventLoop] The event loop
    def self.event_loop
        unless @event_loop
            @event_loop = Utilrb::EventLoop.new
            @event_loop.thread_pool.resize(5,20)
        end
        @event_loop
    end

    # Returns the thread loop used by {Orocos::Async}. It is the same than the
    # one used by {Orocos::Async.event_loop}
    #
    # @return [Utilrb::ThreadPool] The event loop
    def self.thread_pool
        event_loop.thread_pool
    end
end
