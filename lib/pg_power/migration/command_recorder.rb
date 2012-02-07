module PgPower
  module Migration
    module CommandRecorder

      def create_schema(*args)
        record(:create_schema, args)
      end

      def drop_schema(*args)
        record(:drop_schema, args)
      end

      def invert_create_schema(args)
        [:drop_schema, [args.first]]
      end

      def invert_drop_schema(args)
        [:create_schema, [args.first]]
      end




      def set_table_comment(*args)
        record(:set_table_comment, args)
      end

      def remove_table_comment(*args)
        record(:remove_table_comments, args)
      end

      def set_column_comment(*args)
        record(:set_column_comment, args)
      end

      def set_column_comments(*args)
        record(:set_column_comments, args)
      end

      def remove_column_comment(*args)
        record(:remove_column_comment, args)
      end

      def remove_column_comments(*args)
        record(:remove_column_comments, args)
      end

      def invert_set_table_comment(args)
        table_name = args.first
        [:remove_table_comment, [table_name]]
      end

      def invert_set_column_comment(args)
        table_name = args[0]
        column_name = args[1]
        [:remove_column_comment, [table_name, column_name]]
      end

      def invert_set_column_comments(args)
        i_args = [args[0]] + args[1].collect{|name, value| name  }
        [:remove_column_comments, i_args]
      end

    end
  end
end
