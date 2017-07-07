class PhomoRule
  def initialize(rule)
    @rule = init_rule(rule)
  end

  def to_sce
    # combine rule (trg & chg) and conditions
    "#{initial(@rule[0], @rule[1])}#{environment}".strip
  end

  private

  # convert anything that needs outright converting at this initial stage
  def init_rule(rule)
    # categories get square brackets and ? becomes <, also split rule
    r = rule.gsub(/\p{Lu}/,'[\\0]').gsub('?', '<').split('/')
    unless r[0].gsub!('#', '*').nil?
      # change # to * (in TRG) or % (in CHG) when not with _
      r[1].gsub!(/(?<!_)#(?!_)/, '%')
    end
    r[1].gsub!(/(?<!@)\-/, '#') # - becomes # for word-insertions
    r # return ruleset as initialised array
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

  def space_rule?(tester)
    if (sr = /\A((.*)#%)|%#(.*)\z/.match(tester))
      is_prefix = sr[3].nil?
      # return word to add, (bool) prefix? [false = suffix]
      return [(is_prefix ? sr[2] : sr[3]), is_prefix]
    else
      return false
    end
  end

  ####################
  # RULE TRANSLATION #
  ####################
  def initial(trg, chg, literal=false) # (TRG and CHG)
    # empty rule (you never know what blasphemous crap they might try)
    # /
    if trg.empty? && chg.empty?
      return ">"

    # addition
    # /a
  elsif trg.empty?
      return rule_insertion chg, literal

    # subtraction
    # a/
  elsif chg.empty?
      return rule_deletion trg, literal

    # movement from a certain point and length to destination
    # #/>1@3^2   -->   *?{2}@0 > ^?@2
    # #/>#_@_#^2   -->   *?{2} > ^?_# / #_
    # #/>!#_@_#^2   -->   *?{2} > ^_# / #_
    elsif (mp = movement_point_length? chg)
      if /_/ =~ mp[1]
        if /!/ =~ mp[1]
          m_del = false
          mp[1].sub!('!', '')
        else
          m_del = true
        end
        @environment = mp[1]
        return rule_wildcard_cnd_movement mp[0], mp[2], m_del
      else
        return rule_wildcard_movement mp[0], mp[1], mp[2]
      end

    # operation at a certain point and length
    # #/##@1^2   -->   *?{2}@0>%%
  elsif (pd = point_length_operation? chg)
      if pd[0].empty?
        # if no change given, i.e deletion
        return rule_wildcard_deletion pd[2], pd[1], literal
      else
        # if change given, i.e change
        return rule_wildcard_generic pd[0], pd[2], pd[1]
      end

    # insertion at a certain point
    # #/#a@1
    elsif trg == '*' && (ir = insertion_rule? chg)
      if contains_category? chg
        # movement with category
        # #/#C@2   -->   [C]@1 > ^_#
        m_dest = chg.start_with?('%') ? '_#' : '#_'
        return rule_env_movement chg.sub('%', ''), m_dest, false
      else
        # regular insertion
        return rule_point_insertion ir[0], ir[1], literal
      end

    # generic rule at a certain point
    # a@1/e
    elsif (pr = position_rule? chg)
      return rule_point_generic trg, pr[0], pr[1]

    # reverse point and length portion of word
    # #/?3^2   -->   *?{2}@2><
    elsif (lr = reverse_length_rule? chg)
      return rule_position_length_reverse lr[0], lr[1]

    # reverse portion of word from certain point
    # #/?3   -->   *@2><
    elsif (wr = reverse_rule? chg)
      return rule_position_reverse wr

    # insertion of separate word
    # #/#-na   -->   +#na / #_
    # #/na-#   -->   +na# / _#
    elsif (sr = space_rule? chg)
      if literal || !(@rule[2].nil? || @rule[2].empty?)
        return rule_word_insertion sr[0], sr[1], true
      else
        @environment = sr[1] ? env_word_initial : env_word_final
        return rule_word_insertion sr[0], sr[1], false
      end

    # generic change
    # a/e   -->   a > e
    else
      return rule_generic trg, chg
    end
  end

  # ENVIRONMENT #
  # PHOMO   / CND / EXP / ELS
  # SCE     / CND ! EXP > ELS
  # dragon hath awoken
  def environment
    constituents = @rule.length - 2 # what's present in the environment
    # some env may have been passed by the rules, takes priority
    # combine environment given from rules with original phomo environment
    @environment ||= @rule[2] if constituents >= 1
    env_construct(@environment, @rule[3], @rule[4]) # translate constituents
  end

  def check_condition(cnd) # make sure CND is compliant with SCE syntax
    if (cr = /\A([^_]+)#\z/.match(cnd))
      return "##{cr[1]}" # swap a# > #a because phomo is silly
    elsif (cr = /\A#([^_]+)\z/.match(cnd))
      return "#{cr[1]}#" # ditto, vice versa
    elsif (eq = /\A(.+)=(\d+)\z/.match(cnd))
      return "#{eq[1]}{=#{eq[2]}}" # [C]=2  -->  [C]{=2}
    elsif (lg = /\A(.+)=(<|>)(\d+)\z/.match(cnd))
      return "#{lg[1]}{#{lg[2]}#{lg[3]}}" # [C]=<2  -->  [C]{<2}
    else
      return cnd
    end
  end

  # gets tricky because else is like a change, not a check_condition
  def check_else(els)
    # put through translator with original target to mimic as if
    # else were change;
    # literal=true to make sure always x>y syntax
    return initial(@rule[0], els, true).sub(/\A(.*)>/, '').strip
  end

  def env_construct(cnd=nil, exp=nil, els=nil)
    c = "" # init string
    c << " / #{check_condition(cnd)}" unless (cnd.nil? || cnd.empty?) # condition
    c << " ! #{check_condition(exp)}" unless (exp.nil? || exp.empty?) # exception
    c << " > #{check_else(els)}" unless (els.nil? || els.empty?) # else
    c # returns only bits that are applicable (no more ///// rules yay)
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

  def rule_insertion(to, literal=false)
    literal ? rule_generic('', to) : "+#{to}"
  end

  def rule_point_insertion(to, point, literal=false)
    if literal
      return rule_generic point_ind(point), to
    else
      return rule_insertion "#{to}#{point_ind(point)}"
    end
  end

  def rule_deletion(to, literal=false)
    literal ? rule_generic(to, '') : "-#{to}"
  end

  def rule_env_movement(target, environment, delete=true)
    d_op = delete ? '^?' : '^'
    rule_generic target, "#{d_op}#{environment}"
  end

  def rule_movement(target, destination, delete=true)
    rule_env_movement target, point_ind(destination), delete
  end

  def point_ind(point)
    "@#{point}"
  end

  def wildcard_length(length)
    "*?{#{length}}"
  end

  def wildcard_position(position)
    "*#{point_ind(position)}"
  end

  def wildcard_length_position(length, position)
    "#{wildcard_length(length)}#{point_ind(position)}"
  end

  def rule_wildcard_generic(to, length, position)
    rule_generic wildcard_length_position(length, position), to
  end

  def rule_wildcard_deletion(length, position, literal=false)
    rule_deletion wildcard_length_position(length, position), literal
  end

  def rule_wildcard_cnd_movement(length, destination, delete=true)
    rule_env_movement wildcard_length(length), destination, delete
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
    rule_reverse wildcard_length_position(length, position)
  end

  def rule_word_insertion(word, prefix, literal=false)
    if literal
      rule_generic '*', (prefix ? "#{word}#%" : "%##{word}")
    else
      rule_insertion (prefix ? "#{word}#" : "##{word}"), false
    end
  end

  ############################
  # ENVIRONMENT CONSTRUCTORS #
  ############################

  def env_word_final
    "_#"
  end

  def env_word_initial
    "#_"
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
      # read rules line-by-line, translating each >> arr_out
      arr_out << convert_rule(rule)
    end
    arr_out # return output
  end

  private

  def convert_rule(rule)
    r = PhomoRule.new(rule)
    r.to_sce # translate rule using PhomoRule methods
  end

  # load ruleset - will be changed for cws2
  # as won't be from file, but from database
  def load_ruleset
    text=File.open(@filename).read
    @ruleset = text.gsub(/\r\n?/, "\n").split("\n") # split by line
  end
end

def run
  if ARGV[0] # running from command line - will change for cws2
    p2s = Phomo2Sce.new(ARGV[0])
    p2s.to_sce.each_with_index { |x, y| puts "#{y+1}: #{x}" }
  else
    # i'll tell you what's what mate !!
    puts "phomo2sce v0.0.1 (alpha)"
    puts "(c) Fleur Budek"
    puts "syntax: ruby phomo2sce.rb [filename]"
    puts "where [filename] is a newline-separated list of phomo sound changes"
  end
end
run if __FILE__==$0
