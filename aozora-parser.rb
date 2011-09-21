#!/usr/bin/ruby
# vim:set fileencoding=Shift_JIS :

require 'stringio'

module AozoraParser
  module Error # {{{
    class Implementation < StandardError; end
    class NotImplmented < Implementation; end
    class AozoraError < StandardError; end
    class Format < AozoraError; end

    class NoBlockEnd < Format # {{{
      attr_reader :node

      def initialize (node)
        @node = node
        super("Not found block end tag for #{node}")
      end
    end # }}}

    class UnmatchedBlock < Format # {{{
      attr_reader :left_node, :right_node

      def initialize (left_node, right_node)
        @left_node, @right_node = left_node, right_node
        super("Unmatched block tag: Left is #{left_node}, but Right is #{right_node}")
      end
    end # }}}

    class UnexpectedWord < Format # {{{
      attr_reader :word

      def initialize (word = nil)
        @word = word
        msg = 'Unexpected word'
        msg += ": #{word}" if word
        super(msg)
      end
    end # }}}
  end # }}}

  module Util # {{{
    def self.text_to_number (s)
      num = s.tr('０-９', '0-9').tr('一二三四五六七八九', '1-9')
      raise Error::Format.new("Not a number: #{s}") unless /\A\d+\Z/ === num
      num.to_i
    end
  end # }}}

  module Token # {{{
    class Base
      def self.create (line, column, *args)
        obj = self.new(*args)
        obj.instance_variable_set(:@line, line)
        obj.instance_variable_set(:@column, column)
        obj
      end

      attr_reader :line, :column

      def == (rhs)
        self.class == rhs.class
      end
    end

    class Text < Base
      attr_reader :text

      def initialize (text)
        @text = text
      end

      def == (rhs)
        super(rhs) and @text == rhs.text
      end
    end

    class Kanji < Text; end
    class Hiragana < Text; end
    class Katakana < Text; end
    class OtherText < Text; end

    class Ruby < Base
      attr_reader :ruby

      def initialize (ruby)
        @ruby = ruby
      end

      def == (rhs)
        super(rhs) and @ruby == rhs.ruby
      end
    end

    class LineBreak < Base; end
    class RubyBar < Base; end

    class RiceMark < Base # {{{
      def text
        '※'
      end
    end # }}}

    class Annotation < Base
      attr_reader :target, :spec, :whole

      def initialize (text)
        @whole = text

        if m = text.match(/^「([^」]+)」[はに](.+)/)
          @target = m[1]
          @spec = m[2]
        end
      end

      def == (rhs)
        super(rhs) and @whole == rhs.whole and @target == rhs.target and @spec == rhs.spec
      end
    end

    class Tokens < Array; end
  end # }}}

  module Char # {{{
    class Char # {{{
      def == (rhs)
        self.class == rhs.class
      end

      def === (rhs)
        self.class == rhs.class
      end
    end # }}}

    class JIS < Char # {{{
      def self.parse (s)
        m = s.match(/(\d+)-(\d+)(?:-(\d+))?/)
        raise 'No code' unless m
        code = (1 .. 3).map {|i| m[i] } .compact.map {|it| it.to_i }

        if m = s.match(/「([^＋]+＋[^」]+)」/)
          parts = m[1].split(/＋/)
          parts = nil if parts.size < 2
        end

        if m = s.match(/第(.)水準/)
          level = Util.text_to_number(m[1])
        end

        self.new(code, level, parts)
      rescue => e
        raise Error::Format.new("Cannot convert to JIS char (#{e}): #{s}")
      end

      attr_reader :code, :level, :parts

      def initialize (code, level, parts)
        @code, @level, @parts = code, level, parts
      end

      def == (rhs)
        super(rhs) and @code == rhs.code and @level == rhs.level and @parts == rhs.parts
      end

      def === (rhs)
        super(rhs) and @code == rhs.code
      end
    end # }}}

    class Unicode < Char # {{{
      def self.parse(s)
        m = s.match(/unicode/i === s ? /unicode([\da-f]{4})/i : /([\da-f]{4})/i)
        raise 'No code' unless m
        code = m[1].to_i(16)

        if m = s.match(/「([^＋]+＋[^」]+)」/)
          parts = m[1].split(/＋/)
          parts = nil if parts.size < 2
        end

        self.new(code, parts)
      rescue => e
        raise Error::Format.new("Cannot convert to Unicode char (#{e}): #{s}")
      end

      attr_reader :code, :parts

      def initialize (code, parts)
        @code, @parts = code, parts
      end

      def == (rhs)
        super(rhs) and @code == rhs.code and @parts == rhs.parts
      end

      def === (rhs)
        super(rhs) and @code == rhs.code
      end
    end # }}}
  end # }}}

  module Tree # {{{
    class Node # {{{
      PROPERTY_NAMES = [:token]

      def self.create (token, *args)
        obj = self.new(*args)
        obj.instance_variable_set(:@token, token)
        obj
      end

      def self.display_name
        self.name.split(/::/).last
      end

      attr_reader :token

      def line
        @token and @token.line
      end

      def column
        @token and @token.column
      end

      def pretty_print (pp)
        pp.group(
          2,
          "#<T#{self.class.display_name}",
          '>'
        ) do
          names = self.class::PROPERTY_NAMES
          names.each_with_index do
            |name, index|
            pp.breakable
            pp.text "#{name}="
            pp.pp self.instance_variable_get("@#{name}".intern)
          end
        end
      end

      def == (rhs)
        self.class == rhs.class
      end

      def text
        ''
      end
    end # }}}

    class Block < Node # {{{
      include Enumerable

      attr_reader *(PROPERTY_NAMES = [:items])

      def initialize (items = [])
        raise Error::Implementation, "It's not Array: #{items.inspect}" unless Array === items
        @items = items
      end

      def == (rhs)
        super(rhs) and @items == rhs.items
      end

      %w{<< size each [] first last}.each do
        |name|
        define_method(name) do
          |*args, &block|
          @items.__send__(name, *args, &block)
        end
      end

      def text
        @items.map(&:text).join('')
      end

      def last_block_range
        last_lb = nil
        @items.each_with_index.reverse_each {|it, i| break last_lb = i + 1 if Tree::LineBreak === it }
        return (last_lb || 0) .. (@items.size - 1)
      end

      def replace_last_block
        range = self.last_block_range
        new_block = yield Tree::Block.new(@items[range])
        @items[range] = new_block
      end

      def split (position_of_second)
        pos = position_of_second

        @items.each_with_index do
          |node, i|
          pos -= node.text.size
          next unless pos < 0

          l = @items[0 ... i] || []
          r = @items[i + 1 .. -1] || []

          lt = node.text[0 ... pos]
          rt = node.text[pos .. -1]

          l.push(Tree::Text.new(lt)) unless lt.empty?
          r.unshift(Tree::Text.new(rt)) unless rt.empty?

          return [compact(l), compact(r)]
        end

        [compact(@items), nil]
      end

      Matched = Struct.new(:index, :node, :text, :length, :position, :head)

      def split_by_text (t)
        sp = self.text.rindex(t)
        raise Error::Implementation, "Not found the target: #{t}" unless sp

        rest, matched, sz, tsz = t, [], 0, t.size

        self.each_with_index do
          |node, i|
          nts = node.text.size
          sz += nts

          next unless sp < sz

          if matched.empty?
            msz = [sz - sp, tsz].min
            position = nts - (sz - sp)
            head = true
          else
            msz = [nts, tsz].min
            position = msz
            head = false
          end

          tsz -= msz
          rest = t[msz .. - 1]
          matched << Matched.new(i, node, t[0 ... msz], msz == nts ? nil : msz, position, head)

          break if tsz <= 0
        end

        l = @items[0 ... matched.first.index] || []
        r = @items[matched.last.index + 1 .. -1] || []

        c = []
        if matched.size == 1
          m = matched.first
          if m.length
            cl, cr = *m.node.split(m.position)
            l << cl if cl
            crl, crr = cr.split(m.length)
            c << crl
            r << crr if crr
          else
            c << m.node
          end
        else
          matched.each do
            |m|
            unless m.length
              c << m.node
            else
              cl, cr = *m.node.split(m.position)
              if m.head
                l << cl
                c << cr if cr
              else
                c << cl
                if cr
                  r.unshift(cr)
                  break
                end
              end
            end
          end
        end

        l = compact(l)
        c = compact(c)
        r = compact(r)

        [l, c, r]
      end

      private

      def compact (list)
        return nil unless list
        return nil if list.empty?

        if list.all? {|node| Tree::Text === node }
          Tree::Text.new(list.map(&:text).join(''))
        else
          Tree::Block.new(list)
        end
      end
    end # }}}

    class Text < Node # {{{
      attr_reader *(PROPERTY_NAMES = [:text])

      def initialize (text)
        @text = text
      end

      def == (value)
        self.class == value.class and @text == value.text
      end

      def concat (node)
        raise Error::Implementation, "It's not a instance of #{self.class}: #{node}" unless Tree::Text === node
        @text += node.text
      end

      def split (position_of_second)
        l = @text[0 ... position_of_second]
        r = @text[position_of_second .. -1]
        [
          l.empty? ? nil : Text.new(l),
          r.empty? ? nil : Text.new(r)
        ]
      end

      def split_by_text (t)
        sp = @text.rindex(t)
        raise Error::Implementation, "Not found the target: #{t}" unless sp
        ep = sp + t.size - 1

        [
          sp > 0 ? Text.new(@text[0 .. sp - 1]) : nil,
          Text.new(@text[sp .. ep]),
          ep + 1 < @text.size ? Text.new(@text[ep + 1 .. -1]) : nil
        ]
      end
    end # }}}

    class Document < Block; end

    class Break < Node; end
    class LineBreak < Break; end
    class PageBreak < Break; end
    class SheetBreak < Break; end

    class Ruby < Block # {{{
      attr_reader *(PROPERTY_NAMES = superclass::PROPERTY_NAMES + [:ruby])

      def initialize (items = [], ruby = nil)
        super(items)
        @ruby = ruby
      end
    end # }}}

    class Unknown < Node # {{{
      attr_reader *(PROPERTY_NAMES = superclass::PROPERTY_NAMES + [:token])

      def initialize (token)
        super()
        @token = token
      end
    end # }}}

    # Annotations

    class Annotation < Block; end

    class Leveled < Annotation # {{{
      attr_reader *(PROPERTY_NAMES = superclass::PROPERTY_NAMES + [:level])

      def initialize (items = [], level = nil)
        super(items)
        @level = String === level ?  level.tr('０-９', '0-9').to_i : level
      end

      def == (rhs)
        super(rhs) and @level == rhs.level
      end
    end # }}}

    class Bold < Annotation; end
    class Dots < Annotation; end
    class Line < Annotation; end
    class Yoko < Annotation; end
    class Top < Leveled; end
    class Bottom < Leveled; end
    class Heading < Leveled; end

    class Note < Annotation # {{{
      attr_reader *(PROPERTY_NAMES = superclass::PROPERTY_NAMES + [:spec])

      def initialize (items, spec)
        super(items)
        @spec = spec
      end
    end # }}}

    class ExternalChar < Annotation # {{{
      attr_reader *(PROPERTY_NAMES = superclass::PROPERTY_NAMES + [:spec])

      def initialize (items, spec)
        super(items)
        @spec = spec
      end
    end # }}}

    class ExternalCharCode < ExternalChar # {{{
      attr_reader *(PROPERTY_NAMES = superclass::PROPERTY_NAMES + [:char])
      CharClass = nil

      def initialize (items, spec, char = nil)
        super(items, spec)

        if char
          @char = char
        else
          parse_spec
        end
      end

      private

      def parse_spec
        klass = self.class::CharClass
        raise Error::Implementation.new("This class should not be used: #{self.class}") unless klass
        @char = klass.parse(@spec)
      end
    end # }}}

    class JIS < ExternalCharCode
      CharClass = AozoraParser::Char::JIS
    end

    class Unicode < ExternalCharCode
      CharClass = AozoraParser::Char::Unicode
    end
  end # }}}

  class Lexer # {{{
    def self.lex (source)
      instance = self.new
      instance.lex(source)
      instance.tokens
    end

    attr_reader :tokens

    def initialize
      @line_number = 0
      @tokens = Token::Tokens.new
    end

    def lex (source)
      source = StringIO.new(source) if String === source
      read_source(source)
    end

    private

    def read_source (source)
      prev_line = nil

      while line = source.gets
        @line_number += 1

        lb = line.chomp!

        if Pattern::NoteLine === prev_line and /テキスト中に現れる記号について/ === line
          in_notes = true
          @tokens.pop(2)
        end

        unless in_notes
          read_line(line)
          put(Token::LineBreak) if lb
        end

        in_notes = false if in_notes and Pattern::NoteLine === line

        prev_line = line
      end
    end

    def read_line (line)
      buf = ''

      while not line.empty?
        tok, rest =
          read_pattern(/^[ぁ-ん]+/, Token::Hiragana, line) ||
          read_pattern(/^[ァ-ヴ]+/, Token::Katakana, line) ||
          read_pattern(/^[一-龠]+/, Token::Kanji, line) ||
          read_pattern(/^｜/, Token::RubyBar, line) ||
          read_pattern(/^※/, Token::RiceMark, line) ||
          read_pattern(/^《([^》]+)》/, Token::Ruby, line) ||
          read_pattern(/^［＃([^］]+)］/, Token::Annotation, line) ||
          nil

        if tok
          unless buf.empty?
            put(Token::OtherText, buf)
            buf = ''
          end
          put(tok)
        else
          buf += line[0]
          rest = line[1 .. -1]
        end

        line = rest
      end

      put(Token::OtherText, buf) unless buf.empty?
    end

    def read_pattern (pattern, klass, line)
      if m = line.match(pattern)
        [klass.new(m[1] || m.to_s), m.post_match]
      else
        nil
      end
    end

    def put (token, *args)
      if Token::Base === token
        @tokens << token
      else
        # TODO column は未実装
        @tokens << token.create(@line_number, @column, *args)
      end
    end
  end # }}}

  module Pattern # {{{
    NUMS = /[０-９0-9]/
    NoteLine = /\A-{20,}\Z/
  end # }}}

  class Parser # {{{
    Stack = Struct.new(:block, :left_node)

    def self.parse (source)
      parser = self.new
      parser.parse(source)
      parser.tree
    end

    attr_reader :tree

    def initialize
      reset
    end

    def reset
      @tree = Tree::Document.new
      @text_buffer = []
      @current_block = @tree
      @block_stack = []
      @ignore_linebreak = false
      @on_one_line_annotation = false
      @tokens = nil
      @tokens_pos = -1
    end

    def parse (source)
      @tokens = Lexer.lex(source)

      while tok = get_token
        next on_text(tok) if Token::Text === tok

        if Token::Ruby === tok
          if Tree::Ruby === @current_block
            on_not_text
            @current_block.instance_variable_set(:@ruby, tok.ruby)
            exit_block(Tree::Ruby)
          else
            target = @text_buffer.pop
            on_not_text
            put(Tree::Ruby, [Tree::Text.new(target.text)], tok.ruby)
          end
          next
        end

        on_not_text

        if Token::LineBreak === tok
          if @ignore_linebreak
            @ignore_linebreak = false
          else
            put(Tree::LineBreak)
          end

          if @on_one_line_annotation
            exit_block(@on_one_line_annotation)
            @on_one_line_annotation = false
          end

          next
        end

        @ignore_linebreak = false

        case tok
        when Token::Annotation
          on_annotation(tok)
        when Token::RubyBar
          on_ruby_bar(tok)
        when Token::RiceMark
          on_rice_mark(tok)
        else
          put(Tree::Unknown, tok)
        end
      end

      on_not_text
      on_end
    end

    private

    def current_token
      @tokens[@tokens_pos]
    end

    def next_token
      @tokens[@tokens_pos + 1]
    end

    def get_token (klass = nil)
      return unless @tokens_pos < @tokens.size
      @tokens_pos += 1
      result = @tokens[@tokens_pos]
      if not klass or klass === result
        result
      else
        unget_token
        nil
      end
    end

    def get_serial_token (klass)
      result, tok = [], nil
      result << tok while tok = get_token(klass)
      result
    end

    def unget_token
      @tokens_pos -= 1 if @tokens_pos >= 0
    end

    def make_node (node, *args)
      return node if Tree::Node === node
      node = node.create(current_token, *args)
    end

    def put (node, *args)
      node = make_node(node, *args)
      last = @current_block.last
      if Tree::Text === node and Tree::Text === last
        last.concat(node)
      else
        @current_block << node
      end
      node
    end

    def enter_block (left_node, *args)
      left_node = make_node(left_node, *args)
      exit_block(left_node.class) if @current_block.class === left_node
      block = put(left_node)
      raise Error::Implementation, "Not Block: #{block}" unless Tree::Block === block
      @block_stack.push(Stack.new(@current_block, block))
      @current_block = block
    end

    def exit_block (right_node_class)
      old = @block_stack.pop
      raise Error::UnmatchedBlock.new(old.left_node, right_node_class) unless old.left_node.class == right_node_class
      @current_block = old.block
    end

    def on_end
      raise Error::NoBlockEnd.new(@current_block) unless @block_stack.empty?
    end

    def on_text (tok)
      @ignore_linebreak = false
      @text_buffer << tok
    end

    def on_not_text
      return if @text_buffer.empty?
      put(Tree::Text, @text_buffer.map(&:text).join(''))
      @text_buffer = []
    end

    def on_annotation (tok)
      if tok.target
        on_annotation_with_target(tok)
      else
        on_annotation_with_no_target(tok)
      end
    end

    def on_annotation_with_target (tok)
      case tok.spec
      when '太字'
        on_targeted(tok, Tree::Bold)
      when '傍点'
        on_targeted(tok, Tree::Dots)
      when '傍線'
        on_targeted(tok, Tree::Line)
      when '縦中横'
        on_targeted(tok, Tree::Yoko)
      when /\A(.)見出し\Z/
        on_targeted(tok, Tree::Heading, Regexp.last_match[1])
      else
        put(Tree::Unknown, tok)
      end
    end

    def on_annotation_with_no_target (tok)
      @ignore_linebreak = true
      case tok.whole
      when /\Aここから(?:引用文、?)?(#{Pattern::NUMS}+)字下げ?\Z/
        enter_block(Tree::Top, [], Regexp.last_match[1])
      when /\A(?:ここで字下げ|引用文)(?:終わ?り|、.+終わ?り)\Z/
        exit_block(Tree::Top)
      when /\A(?:ここ(?:から|より))(?:地付き|、?地(?:から|より))(?:(#{Pattern::NUMS}+)字(?:空き|上げ|アキ))?\Z/
        enter_block(Tree::Bottom, [], Regexp.last_match[1])
      when /\Aここで、?(?:地付き|、?地上げ|字上げ)終わ?り\Z/
        exit_block(Tree::Bottom)
      when /\A改(?:ページ|頁)\Z/
        put(Tree::PageBreak)
      when /\A改丁\/Z/
        put(Tree::SheetBreak)
      when /\A(?:天から)?(#{Pattern::NUMS}+)字下げ?\Z/
        on_indent(Tree::Top, Regexp.last_match[1])
      when /\A(?:地付き|、?地(?:から|より))(?:(#{Pattern::NUMS}+)字(?:空き|上げ|アキ))?/
        on_indent(Tree::Bottom, Regexp.last_match[1])
      else
        @ignore_linebreak = false
        put(Tree::Unknown, tok)
      end
    end

    def on_targeted (tok, klass, *args)
      @current_block.replace_last_block do
        |block|
        l, c, r = block.split_by_text(tok.target)
        [*l, klass.new(Tree::Block === c ? c.items : [c], *args), *r]
      end
    end

    def on_indent (klass, level)
      if klass == Tree::Top
        raise Error::UnexpectedWord unless @current_block.last == nil or Tree::Break === @current_block.last
      end
      @ignore_linebreak = false
      enter_block(klass, [], level)
      @on_one_line_annotation = klass
    end

    def on_ruby_bar (tok)
      enter_block(Tree::Ruby) unless Token::RiceMark === next_token
    end

    def on_rice_mark (tok)
      marks_text = [tok].concat(get_serial_token(Token::RiceMark)).map(&:text).join('')
      annotation = get_token(Token::Annotation)
      if annotation
        on_note(marks_text, annotation)
      else
        put(Tree::Text, marks_text)
      end
    end

    def on_note (marks_text, annotation)
      inner = [Tree::Text.new(marks_text)]
      case annotation.whole
      when /unicode/i
        put(Tree::Unicode, inner, annotation.whole)
      when /水準|\d+-\d+/i
        put(Tree::JIS, inner, annotation.whole)
      else
        put(Tree::Note, inner, annotation.whole)
      end
    end
  end # }}}

  class TreeWalker # {{{
    def start (tree)
      walk(tree)
      on_end
    end

    private

    def on_node (node, level, &block)
      name = node.class.display_name
      indent = '  ' * level
      if block_given?
        puts "#{indent}<#{name}>"
        yield
        puts "#{indent}</#{name}>"
      else
        puts "#{indent}<#{name} />"
      end
    end

    def on_end
    end

    def walk (node, level = 0)
      if AozoraParser::Tree::Block === node
        on_node(node, level) do
          node.items.each do
            |child|
            walk(child, level + 1)
          end
        end
      else
        on_node(node, level)
      end
    end
  end # }}}

  def self.make_simple_inspect # {{{
    require 'pp'
    Tree::Node.class_eval do
      def inspect
        "\n" + PP.pp(self, '')
      end
    end
  end # }}}
end
