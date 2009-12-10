# Proof-of-concept: symbolic expressions in Ruby (inspired by Sage)

class Symbolic

  INFIX_OPERATORS = {
    :+ => lambda{|x,y| x+y},
    :- => lambda{|x,y| x-y},
    :* => lambda{|x,y| x*y},
    :/ => lambda{|x,y| x/y},
    :^ => lambda{|x,y| x**y}, # nice, but wrong precedence!
    :** => lambda{|x,y| x**y}
  }

  PREFIX_OPERATORS = {
    :+ => lambda{|x| +x},
    :- => lambda{|x| -x}
  }

  FUNCTIONS = {
    :sin=>lambda{|x| Math.sin(x)},
    :cos=>lambda{|x| Math.cos(x)},
    :tan=>lambda{|x| Math.tan(x)},
    :asin=>lambda{|x| Math.asin(x)},
    :acos=>lambda{|x| Math.acos(x)},
    :atan=>lambda{|x| Math.atan(x)},
    :atan2=>lambda{|y,x| Math.atan2(y,x)},
    :sqrt=>lambda{|x| Math.sqrt(x)},
    :abs=>lambda{|x| x.abs}
  }

  class Expression

    def initialize(*tree)
      @tree = tree
    end

    attr_reader :tree

    INFIX_OPERATORS.each_key do |operator|
      define_method operator do |other|
        other = Expression.new(other) unless other.is_a?(Expression)
        #Expression.new(operator, self.tree, other.tree)
        Expression.new(operator, self, other)
      end
    end

    PREFIX_OPERATORS.each_key do |operator|
      define_method :"#{operator}@" do
        Expression.new(operator, self)
      end
    end

    def vars
      vars = []
      if @tree.size==1
        if @tree.first.is_a?(Symbol)
          unless f=FUNCTIONS[@tree.first] && f.arity==0
            vars << @tree.first if @tree.first.is_a?(Symbol)
          end
        end
        # TODO: allow an Expression here?
      else
        @tree[1..-1].each do |subexpr|
          case subexpr
          when Expression
            vars += subexpr.vars
          when Symbol
            vars << subexpr
          end
        end
      end
      vars.uniq
    end

    def to_s
      arity = tree.size - 1
      case tree.first
        when Symbol
          if arity==2 && INFIX_OPERATORS.has_key?(tree.first)
            "(#{tree[1].to_s} #{tree.first} #{tree[2].to_s})"
          elsif arity==1 && PREFIX_OPERATORS.has_key?(tree.first)
            "(#{tree.first} #{tree[1].to_s})"
          elsif (f = FUNCTIONS[tree.first]) && f.arity==arity
            "#{tree.first}(#{tree[1..-1].map{|x| x.to_s}.join(',')})"
          else
            tree.first
          end
        else
         tree.first
      end
    end

    def eval(values={})
      arity = tree.size - 1
      case tree.first
        when Symbol
          if arity==2 && op = INFIX_OPERATORS[tree.first]
            op[Expression.eval(tree[1],values), Expression.eval(tree[2],values)]
          elsif arity==1 && op = PREFIX_OPERATORS[tree.first]
            op[Expression.eval(tree[1],values)]
          elsif (f = FUNCTIONS[tree.first]) && f.arity==arity
            f[*tree[1..-1].map{|x| Expression.eval(x,values)}]
          else
            # assume variable
            values[tree.first] || self
          end
        else
         tree.first
      end
    end

    def self.eval(item, values)
      case item
        when Expression
          item.eval(values)
        else
          item
      end
    end

    def coerce(other)
      [Expression.new(other), self]
    end

  end

  def self.fun(name, mthd=nil, &blk)
    raise ArgumentError,"Invalid function definition" unless (mthd || blk) && (!mthd || !blk)
    blk ||= mthd
    name = name.to_sym
    arity = blk.arity
    FUNCTIONS[name] = blk # TODO: local functions (per Symbolic object)
    define_method name do |*args|
    if arity != args.size
      raise ArgumentError,"Invalid number of arguments for  #{name} (#{args.size} for #{arity})"
    end
      Expression.new(name, *args)
    end
  end

  FUNCTIONS.each_pair do |f, mth|
    Symbolic.fun f, mth
  end

  def initialize
    @vars = {}
  end

  attr_reader :vars

  def var(*names)
    names.each do |name|
      name = name.to_sym
      @vars[name] = nil
      instance_variable_set "@#{name}", Expression.new(name)
      self.class.class_eval{
        attr_reader name
        # can't decide on assignment syntax:
        # 1. assignment operator (requires self) self.x = 1.0;
        define_method :"#{name}=" do |value|
          assign name, value
        end
        # 2. method assign_x 1.0;
        define_method :"assign_#{name}" do |value|
          assign name, value
        end
        # 3. or use assing :x, 1.0;
        # More indecision: rename 'assign' to 'set' ? 'let' ?
      }
    end
  end

  def assign(name, value)
    @vars[name.to_sym] = value
  end

  def execute(blk)
    if blk.arity==1
      blk.call(self)
    else
      self.instance_eval(&blk)
    end
  end

  def eval(expr, values={})
    expr.eval(@vars.merge(values))
  end

  def fun(name, mthd=nil, &blk)
    self.class.fun name, mthd, &blk
  end

  def macro(name, &blk)
    self.class.class_eval{define_method name, blk}
  end

end

def symbolic(*args, &blk)
  s = Symbolic.new(*args)
  s.execute blk
end


# TODO:
# consider this: add reference to Symbolic object in Expression;
# use it to access local functions defined for a Symbolic (not
# globally in FUNCTIONS as now) and to access variables, so
# expr.eval can be used instead of eval(expr)
