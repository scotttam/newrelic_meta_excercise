class Object 
  def eigenclass 
    class << self; self; end
  end
  
  def method_owner(method_name)
    instance_method(method_name.to_sym).owner
  rescue NameError
  end
  
  #Ruby 2.0 Module.const_get supports A::B syntax. Older versions do not so walk the list.
  def self.constantize_classes(class_names)
    if RUBY_VERSION == '2.0.0'
      Module.const_get(class_names)
    else
      classes = [Module]
      class_names.split('::').each { |klass_str| classes << classes.last.const_get(klass_str) }
      classes.last
    end
  rescue NameError
  end
end

class Instrumentator
  class << self
    attr_reader :call_count, :method_name
  end

  private_class_method :new

  def self.init_and_install
    @class_names, @scope, @method_name = ENV['COUNT_CALLS_TO'].split(/([#.])/)
    @call_count = 0
    @currently_instrumenting = false
    @installed = []
    target_class_constant ? install_method_instrumentation : install_dynamic_hooks
  end

  def self.install_method_instrumentation
    instrumenting do |method_owner|
      method_owner.class_eval <<-EVAL
        def #{scrubbed_method_name}_with_instrumentation(*args, &block)
          #{scrubbed_method_name}_without_instrumentation(*args, &block)
          Instrumentator.increment_call_count
        end
  
        alias_method :#{scrubbed_method_name}_without_instrumentation, :#{method_name}
        alias_method :#{method_name}, :#{scrubbed_method_name}_with_instrumentation
      EVAL
    end
  end
 
  def self.target_class_constant
    @klass ||= constantize_classes(@class_names)
  end

  def self.increment_call_count
    @call_count += 1
  end
  
  def self.instance_scope?
    (@scope == '#')
  end

  def self.instrumenting
    return if @currently_instrumenting
    return unless Instrumentator.target_class_constant
    target = Instrumentator.instance_scope? ? Instrumentator.target_class_constant : Instrumentator.target_class_constant.eigenclass
    return unless method_owner = target.method_owner(method_name)
    return if @installed.include?([method_owner, method_name])
    @currently_instrumenting = true
    
    yield(method_owner)
    
    @installed << [method_owner, method_name]
    @currently_instrumenting = false  
  end
  
  private_class_method :instrumenting

  def self.scrubbed_method_name
    case method_name_trailing_punctuation_removed = method_name.gsub(/[(?!=)]/, '')
      when "*"
        'star'
      when "/"
        'slash'
      when "+"
        'plus'
      when "-"
        'minus'
      when "[]"
        'brackets'
      else
        method_name_trailing_punctuation_removed
    end
  end
  
  private_class_method :scrubbed_method_name
  
  def self.install_dynamic_hooks
    Module.class_eval do
      def included(base)
        instrument(base)
      end
      
      if RUBY_VERSION == '2.0.0'
        #Ruby 2.0 introduced the ability to prepend Modules into classes
        def prepended(base)
          instrument(base)
        end
      end

      def extended(base)
        instrument(base)

        if Instrumentator.target_class_constant
          def self.method_added(method_name)
            if method_name.to_s == Instrumentator.method_name
              Instrumentator.install_method_instrumentation
            end
          end
        end
      end

      private
      def instrument(base)
        super(base) if defined?(super)
        Instrumentator.install_method_instrumentation
      end
    end
    
    Class.class_eval do
      def inherited(base)
        super if defined?(super)
        
        if Instrumentator.target_class_constant == base
          Instrumentator.install_method_instrumentation

          if Instrumentator.instance_scope?
            def method_added(method_name)
              if method_name.to_s == Instrumentator.method_name
                Instrumentator.install_method_instrumentation
              end
            end
          else
            def singleton_method_added(method_name)
              if method_name.to_s == Instrumentator.method_name
                Instrumentator.install_method_instrumentation
              end 
            end
          end

        end
      end
    end
  end

  private_class_method :install_dynamic_hooks
end

Instrumentator.init_and_install
at_exit { puts "#{ENV['COUNT_CALLS_TO']} called #{Instrumentator.call_count} times" }
