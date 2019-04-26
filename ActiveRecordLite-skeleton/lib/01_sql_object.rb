require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject

  def self.columns
    return @columns if @columns
    columns = DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM
        #{self.table_name}
      LIMIT
        0
    SQL
    @columns = columns.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |column|

      define_method(column) do
        self.attributes[column]
      end

      define_method("#{column}=") do |arg|
        self.attributes[column] = arg
      end

    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
  end

  def self.all
    all = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL
    parse_all(all)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    treasure = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
    SQL

    parse_all(treasure)[0]

  end

  def initialize(params = {})
    # params.each do |k, v|
    #   self.class.table_name = k
  
    params.each do |key, value|
      key = key.to_sym
      if self.class.columns.include?(key)
        self.send("#{key}=", value)
      else
        raise "unknown attribute '#{key}'"
      end
    end

  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    @attributes.values
  end

  def insert
    columns = self.class.columns.drop(1)
    col_names = columns.map(&:to_s).join(", ")
    question_marks = (["?"] * columns.count).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    columns = self.class.columns.drop(1)
    col_names_to_update = columns.join(" = ?, ") + " = ?"

    DBConnection.execute(<<-SQL, *attribute_values.drop(1), id)
      UPDATE
        #{self.class.table_name}
      SET
        #{col_names_to_update}
      WHERE
        #{self.class.table_name}.id = ?
    SQL

  end

  def save
    id.nil? ? self.insert : self.update
  end
end
