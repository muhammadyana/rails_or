require 'rails_or/version'
require 'rails_or/where_binding_mixs'
require 'active_record'
require 'rails_or/patches/null_relation' if defined?(ActiveRecord::NullRelation)
require 'rails_or/active_record/extension'

module RailsOr
  IS_RAILS3_FLAG = Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.0.0')
  IS_RAILS5_FLAG = Gem::Version.new(ActiveRecord::VERSION::STRING) >= Gem::Version.new('5.0.0')
  FROM_VALUE_METHOD = %i[from_value from_clause].find{|s| ActiveRecord::Relation.method_defined?(s) }
  ASSIGN_FROM_VALUE = :"#{FROM_VALUE_METHOD}="

  class << self
    def values_to_arel(values)
      values.map!{|x| wrap_arel(x) }
      return (values.size > 1 ? Arel::Nodes::And.new(values) : values)
    end

    def spwan_relation(relation, method, condition)
      new_relation = relation.klass.send(method, condition)
      new_relation.send(ASSIGN_FROM_VALUE, relation.send(FROM_VALUE_METHOD))
      copy_values(new_relation, relation) if IS_RAILS5_FLAG
      return new_relation
    end

    def get_current_scope(relation)
      return relation.clone if IS_RAILS3_FLAG
      # ref: https://github.com/rails/rails/blob/17ef58db1776a795c9f9e31a1634db7bcdc3ecdf/activerecord/lib/active_record/scoping/named.rb#L26
      # return relation.all # <- cannot use this because some gem changes this method's behavior
      return (relation.current_scope || relation.default_scoped).clone
    end

    def parse_parameter(relation, *other)
      other = other.first if other.size == 1
      case other
      when Hash   ; spwan_relation(relation, :where, other)
      when Array  ; spwan_relation(relation, :where, other)
      when String ; spwan_relation(relation, :where, other)
      else        ; other
      end
    end

    private

    def wrap_arel(node)
      return node if Arel::Nodes::Equality === node
      return Arel::Nodes::Grouping.new(String === node ? Arel.sql(node) : node)
    end

    def copy_values(to, from) # For Rails 5
      to.joins_values      = from.joins_values
      to.limit_value       = from.limit_value
      to.group_values      = from.group_values
      to.distinct_value    = from.distinct_value
      to.order_values      = from.order_values
      to.offset_value      = from.offset_value
      to.references_values = from.references_values
    end
  end
end
