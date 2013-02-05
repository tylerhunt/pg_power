module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    # Patched version:  3.1.3
    # Patched methods::
    #   * indexes
    class PostgreSQLAdapter
      # In Rails3.2 method #extract_schema_and_table is moved into Utils module.
      # In Rails3.1 it's implemented right in PostgreSQLAdapter class.
      # So it's Rails3.2 we include the module into PostgreSQLAdapter in order to make
      # it compatible to Rails3.1
      # -- sergey.potapov 2012-06-25
      if ActiveRecord::VERSION::STRING =~ /^3\.2/
        include self::Utils
      end

      # Regex to find columns used in index statements
      INDEX_COLUMN_EXPRESSION = /ON \w+(?: USING \w+ )?\((.+)\)/
      # Regex to split column expression into columns (accounts for functions)
      INDEX_COLUMNS_EXPRESSION = /(\w+|\w+\(.*\))(?:,|$)/
      # Regex to find where clause in index statements
      INDEX_WHERE_EXPRESION = /WHERE (.+)$/

      # Returns an array of indexes for the given table.
      #
      # == Patch 1 reason:
      # Since {ActiveRecord::SchemaDumper#tables} is patched to process tables
      # with a schema prefix, the {#indexes} method receives table_name as
      # "<schema>.<table>". This patch allows it to handle table names with
      # a schema prefix.
      #
      # == Patch 1:
      # Search using provided schema if table_name includes schema name.
      #
      # == Patch 2 reason:
      # {ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#indexes} is patched
      # to support partial indexes using :where clause.
      #
      # == Patch 2:
      # Search the postgres indexdef for the where clause and pass the output to
      # the custom {PgPower::ConnectionAdapters::IndexDefinition}
      #
      def indexes(table_name, name = nil)
        schema, table = extract_schema_and_table(table_name)
        schemas = schema ? "ARRAY['#{schema}']" : 'current_schemas(false)'

        result = query(<<-SQL, name)
          SELECT distinct i.relname, d.indisunique, d.indkey,  pg_get_indexdef(d.indexrelid), t.oid, am.amname
          FROM pg_class t
          INNER JOIN pg_index d ON t.oid = d.indrelid
          INNER JOIN pg_class i ON d.indexrelid = i.oid
          INNER JOIN pg_am    am ON i.relam = am.oid
          WHERE i.relkind = 'i'
            AND d.indisprimary = 'f'
            AND t.relname = '#{table}'
            AND i.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = ANY (#{schemas}) )
         ORDER BY i.relname
        SQL

        result.map do |row|
          index = {
            :name          => row[0],
            :unique        => row[1] == 't',
            :keys          => row[2].split(" "),
            :definition    => row[3],
            :id            => row[4],
            :access_method => row[5]
          }

          column_names = find_column_names(table_name, index)

          unless column_names.empty?
            where   = find_where_statement(index)
            lengths = find_lengths(index)

            PgPower::ConnectionAdapters::IndexDefinition.new(table_name, index[:name], index[:unique], column_names, lengths, where, index[:access_method])
          end
        end.compact
      end

      # Find column names from index attributes. If the columns are virtual (ie
      # this is an expression index) then it will try to return the functions
      # that represent each column
      #
      # @param [String] table_name the name of the table
      # @param [Hash] index index attributes
      # @return [Array]
      def find_column_names(table_name, index)
        columns = Hash[query(<<-SQL, "Columns for index #{index[:name]} on #{table_name}")]
          SELECT a.attnum, a.attname
          FROM pg_attribute a
          WHERE a.attrelid = #{index[:id]}
          AND a.attnum IN (#{index[:keys].join(",")})
        SQL

        if index[:keys].include?('0')
          definition = index[:definition].sub(INDEX_WHERE_EXPRESION, '')

          if column_expression = definition.match(INDEX_COLUMN_EXPRESSION)[1]
            column_expressions = column_expression.scan(INDEX_COLUMNS_EXPRESSION).flatten.map do |functional_name|
              remove_type(functional_name)
            end
          else
            column_expressions = []
          end
        end

        index[:keys].collect.with_index do |key, index|
          columns.fetch(key) { column_expressions[index] }
        end
      end

      # Find where statement from index definition
      #
      # @param [Hash] index index attributes
      # @return [String] where statement
      def find_where_statement(index)
        index[:definition].scan(INDEX_WHERE_EXPRESION).flatten[0]
      end

      # Find length of index
      # TODO Update lengths once we merge in ActiveRecord code that supports it. -dresselm 20120305
      #
      # @param [Hash] index index attributes
      # @return [Array]
      def find_lengths(index)
        []
      end

      # Remove type specification from stored Postgres index definitions
      #
      # @param [String] column_with_type the name of the column with type
      # @return [String]
      #
      # @example
      #   remove_type("((col)::text")
      #   => "col"
      def remove_type(column_with_type)
        column_with_type.sub(/\((\w+)\)::\w+/, '\1')
      end
    end
  end
end
