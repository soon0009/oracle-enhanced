module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.oracle_enhanced_connection(config) #:nodoc:
      if config[:emulate_oracle_adapter] == true
        # allows the enhanced adapter to look like the OracleAdapter. Useful to pick up
        # conditionals in the rails activerecord test suite
        require 'active_record/connection_adapters/emulation/oracle_adapter'
        ConnectionAdapters::OracleAdapter.new(
          ConnectionAdapters::OracleEnhancedConnection.create(config), logger, config)
      else
        ConnectionAdapters::OracleEnhancedAdapter.new(
          ConnectionAdapters::OracleEnhancedConnection.create(config), logger, config)
      end
    end

    # Specify table columns which should be ignored by ActiveRecord, e.g.:
    # 
    #   ignore_table_columns :attribute1, :attribute2
    def self.ignore_table_columns(*args)
      connection.ignore_table_columns(table_name,*args)
    end

    # Specify which table columns should be typecasted to Date (without time), e.g.:
    # 
    #   set_date_columns :created_on, :updated_on
    def self.set_date_columns(*args)
      connection.set_type_for_columns(table_name,:date,*args)
    end

    # Specify which table columns should be typecasted to Time (or DateTime), e.g.:
    # 
    #   set_datetime_columns :created_date, :updated_date
    def self.set_datetime_columns(*args)
      connection.set_type_for_columns(table_name,:datetime,*args)
    end

    # Specify which table columns should be typecasted to boolean values +true+ or +false+, e.g.:
    # 
    #   set_boolean_columns :is_valid, :is_completed
    def self.set_boolean_columns(*args)
      connection.set_type_for_columns(table_name,:boolean,*args)
    end

    # Specify which table columns should be typecasted to integer values.
    # Might be useful to force NUMBER(1) column to be integer and not boolean, or force NUMBER column without
    # scale to be retrieved as integer and not decimal. Example:
    # 
    #   set_integer_columns :version_number, :object_identifier
    def self.set_integer_columns(*args)
      connection.set_type_for_columns(table_name,:integer,*args)
    end

    # Specify which table columns should be typecasted to string values.
    # Might be useful to specify that columns should be string even if its name matches boolean column criteria.
    # 
    #   set_string_columns :active_flag
    def self.set_string_columns(*args)
      connection.set_type_for_columns(table_name,:string,*args)
    end

    # After setting large objects to empty, select the OCI8::LOB
    # and write back the data.
    if ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR >= 1
      before_update :record_changed_lobs
      after_update :enhanced_write_lobs
    else
      before_update :record_changed_lobs
      after_save :enhanced_write_lobs
    end
    def enhanced_write_lobs #:nodoc:
      if connection.is_a?(ConnectionAdapters::OracleEnhancedAdapter) &&
          !(self.class.custom_create_method || self.class.custom_update_method)
        connection.write_lobs(self.class.table_name, self.class, attributes, @changed_lob_columns || self.class.lob_columns)
      end
    end
    def record_changed_lobs
      @changed_lob_columns = self.class.lob_columns.select do |col|
        self.class.serialized_attributes.keys.include?(col.name) ||
          (self.send(:"#{col.name}_changed?") && !self.class.readonly_attributes.to_a.include?(col.name))
      end
    end
    private :enhanced_write_lobs
    private :record_changed_lobs

    # Get table comment from schema definition.
    def self.table_comment
      connection.table_comment(self.table_name)
    end

    def self.lob_columns
      columns.select do |column|
        column.respond_to?(:lob?) && column.lob?
      end
    end

    def self.virtual_columns
      columns.select do |column|
        column.respond_to?(:virtual?) && column.virtual?
      end
    end

    if ActiveRecord::VERSION::MAJOR < 3
      def attributes_with_quotes_with_virtual_columns(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
        virtual_column_names = self.class.virtual_columns.map(&:name)
        attributes_with_quotes_without_virtual_columns(include_primary_key, include_readonly_attributes, attribute_names - virtual_column_names)
      end

      alias_method_chain :attributes_with_quotes, :virtual_columns
    else
      def arel_attributes_values_with_virtual_columns(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
        virtual_column_names = self.class.virtual_columns.map(&:name)
        arel_attributes_values_without_virtual_columns(include_primary_key, include_readonly_attributes, attribute_names - virtual_column_names)
      end

      alias_method_chain :arel_attributes_values, :virtual_columns
    end

  end

end
