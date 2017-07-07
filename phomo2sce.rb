class PhomoRule
  def initialize(rule)
    @rule = init_rule(rule)
  end

  def to_sce
    "#{initial}#{environment}"
  end

  private

  def init_rule(rule)
    rule.gsub(/\p{Lu}/,'[\\0]').gsub('?', '<').split('/')
  end

  ################
  # RULE TESTERS #
  ################
  def insertion_rule?(tester)
    if (ir = /\A(.+%|%.+)@((-)?[0-9]+)\z/.match(tester))
      # return thing to be inserted, position of insertion
      return [ir[1].sub('%', ''), ir[2]]
    else
      return false # no fuq u
    end
  end

  def position_rule?(tester)
    if (pr = /\A(.)+@((-)?[0-9]+)\z/.match(tester))
      # return rule without position, position
      return [pr[1], pr[2]]
    else
      return false # no fuq u
    end
  end

  def contains_category?(tester)
    /\[.\]/.match(tester)
  end

  def point_length_operation?(tester)
    if (pd = /\A(.*)@(\d+)\^(\d+)\z/.match(tester))
      # return change, position, number of chars to duplicate
      return [pd[1], pd[2], pd[3]]
    else
      return false
    end
  end

  def movement_point_length?(tester)
    if (mp = /\A>(.+)@(.+)\^(\d+)\z/.match(tester))
      # return length, point, destination
      return [mp[3], mp[1], mp[2]]
    else
      return false
    end
  end

  def reverse_rule?(tester)
    if (wr = /\A<(\d+)\z/.match(tester))
      return wr[1]
    else
      return false
    end
  end

  def reverse_length_rule?(tester)
    if (lr = /\A<(\d+)\^(\d+)\z/.match(tester))
      # return position, length
      return [lr[1], lr[2]]
    else
      return false
    end
  end

  ####################
  # RULE TRANSLATION #
  ####################
  def initial
    unless @rule[0].gsub!('#', '*').nil?
      # change # to * (TRG) or % (CHG) when not with _
      @rule[1].gsub!(/(?<!_)#(?!_)/, '%')
    end

    # empty rule (you never know what blasphemous shit they might try)
    # /
    if @rule[0].empty? && @rule[1].empty?
      return ">"

    # addition
    # /a
    elsif @rule[0].empty?
      return rule_insertion @rule[1]

    # subtraction
    # a/
    elsif @rule[1].empty?
      return rule_deletion @rule[0]

    # movement from a certain point and length to destination
    # #/>1@3^2   -->   *?{2}@0>^?@2
    # #/>#_@_#^2   -->   *?{2} > ^?_#/#_
    # #/>!#_@_#^2   -->   *?{2} > ^_#/#_
    elsif (mp = movement_point_length? @rule[1])
      if /_/ =~ mp[1]
        if /!/ =~ mp[1]
          m_del = false
          mp[1].sub!('!', '')
        else
          m_del = true
        end
        @environment = " / #{mp[1]}"
        return rule_wildcard_env_movement mp[0], mp[2], m_del
      else
        return rule_wildcard_movement mp[0], mp[1], mp[2]
      end

    # operation at a certain point and length
    # #/##@1^2   -->   *?{2}@0>%%
    elsif (pd = point_length_operation? @rule[1])
      if pd[0].empty?
        # if no change given, i.e deletion
        return rule_wildcard_deletion(pd[2], pd[1])
      else
        # if change given, i.e change
        return rule_wildcard_generic(pd[0], pd[2], pd[1])
      end

    # insertion at a certain point
    # #/#a@1
    elsif @rule[0] == '*' && (ir = insertion_rule? @rule[1])
      if contains_category? @rule[1]
        # movement with category
        # #/#C@2   -->   [C]@1 > ^_#
        m_dest = @rule[1].start_with?('%') ? '_#' : '#_'
        return rule_env_movement @rule[1].sub('%', ''), m_dest, false
      else
        # regular insertion
        return rule_point_insertion ir[0], ir[1]
      end

    # generic rule at a certain point
    # a@1/e
    elsif (pr = position_rule? @rule[1])
      return rule_point_generic @rule[0], pr[0], pr[1]

    # reverse point and length portion of word
    # #/?3^2   -->   *?{2}@2><
    elsif (lr = reverse_length_rule? @rule[1])
      return rule_position_length_reverse lr[0], lr[1]

    # reverse portion of word from certain point
    # #/?3   -->   *@2><
    elsif (wr = reverse_rule? @rule[1])
      return rule_position_reverse wr

    else # generic change, eg: a/e
      return rule_generic @rule[0], @rule[1]
    end
  end

  def environment # for each environment, add blank space before for readability
    #TODO: check in @environment for things already there
    # =>  (thrown out from the initial rules)
    @environment ? @environment : " / ENV"
  end

  #####################
  # RULE CONSTRUCTORS #
  #####################
  def rule_generic(from, to)
    "#{from} > #{to}"
  end

  def rule_point_generic(from, to, point)
    rule_generic "#{from}@#{point}", to
  end

  def rule_insertion(to)
    "+#{to}"
  end

  def rule_point_insertion(to, point)
    rule_insertion "#{to}@#{point}"
  end

  def rule_deletion(to)
    "-#{to}"
  end

  def rule_env_movement(target, environment, delete=true)
    d_op = delete ? '^?' : '^'
    "#{target} > #{d_op}#{environment}"
  end

  def rule_movement(target, destination, delete=true)
    rule_env_movement target, "@#{destination}", delete
  end

  def wildcard_length(length)
    "*?{#{length}}"
  end

  def wildcard_position(position)
    "*@#{position}"
  end

  def wildcard_length_position(length, position)
    "#{wildcard_length(length)}@#{position}"
  end

  def rule_wildcard_generic(to, length, position)
    rule_generic wildcard_length_position(length, position), to
  end

  def rule_wildcard_deletion(length, position)
    rule_deletion wildcard_length_position(length, position)
  end

  def rule_wildcard_movement(length, position, destination, delete=true)
    rule_movement wildcard_length_position(length, position), destination, delete
  end

  def rule_wildcard_env_movement(length, destination, delete=true)
    rule_movement wildcard_length(length), destination, delete
  end

  def rule_reverse(target)
    rule_generic target, "<"
  end

  def rule_position_reverse(position)
    rule_reverse wildcard_position(position)
  end

  def rule_position_length_reverse(position, length)
    rule_reverse wildcard_length_position(position, length)
  end
end

class Phomo2Sce
  def initialize(filename)
    @filename = filename
    load_ruleset
  end

  def to_sce
    arr_out = Array.new
    @ruleset.each do |rule|
      arr_out << convert_rule(rule)
    end
    arr_out
  end

  private

  def convert_rule(rule)
    r = PhomoRule.new(rule)
    r.to_sce
  end

  def load_ruleset
    line_num=0
    text=File.open(@filename).read
    text.gsub!(/\r\n?/, "\n")
    @ruleset = text.split("\n")
  end
end

if ARGV[0]
  p2s = Phomo2Sce.new(ARGV[0])
  p2s.to_sce.each_with_index { |x, y| puts "#{y+1}: #{x}" }
else
  puts "(c) Fleur B"
  puts "use filename of sample sound changes"
end
