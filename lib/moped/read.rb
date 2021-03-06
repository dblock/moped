# encoding: utf-8
module Moped

  # Represents a read from the database that is executed on a specific node
  # determined by a read preference.
  #
  # @since 2.0.0
  class Read

    # @!attribute database
    #   @return [ String ] The database the read is from.
    # @!attribute operation
    #   @return [ Protocol::Query, Protocol::GetMore, Protocol::Command,
    #     Protocol::KillCursors ] The read operation.
    attr_reader :database, :operation

    # Instantiate the read operation.
    #
    # @example Instantiate the read.
    #   Read.new(get_more)
    #
    # @param [ Protocol::Query, Protocol::GetMore, Protocol::Command,
    #   Protocol::KillCursors ] operation The read operation.
    #
    # @since 2.0.0
    def initialize(operation)
      @operation = operation
      @database = operation.database
    end

    # Execute the read operation on the provided node. If the query failed, we
    # will check if the failure was due to authorization and attempt the
    # operation again. This could sometimes happen in the case of a step down
    # or reconfiguration on the server side.
    #
    # @example Execute the operation.
    #   read.execute(node)
    #
    # @param [ Node ] node The node to execute the read on.
    #
    # @raise [ Failure ] If the read operation failed.
    #
    # @return [ Protocol::Reply ] The reply from the database.
    #
    # @since 2.0.0
    def execute(node)
      node.process(operation) do |reply|
        if reply.query_failed?
          if reply.unauthorized? && node.auth.has_key?(database)
            node.login(database, *node.auth[database])
            return execute(node)
          else
            raise Failure.new(operation, reply.documents.first)
          end
        end
        reply
      end
    end

    # This exception is raised when a query fails to execute. This could be due
    # to some sort of reconfiguration.
    #
    # @since 2.0.0
    class Failure < Errors::PotentialReconfiguration; end
  end
end
