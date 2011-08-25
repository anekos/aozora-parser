#!/usr/bin/ruby
# vim:set fileencoding=cp932 :

require 'stringio'

module AozoraParser
  module Error # {{{
    class Implementation < StandardError; end
    class NotImplmented < Implementation; end
    class AozoraError < StandardError; end
    class Format < AozoraError; end

    class NoBlockEnd < Format # {{{
      def initialize (node)
        super("Not found block end tag for #{node}")
      end
    end # }}}

    class UnmatchedBlock < Format # {{{
      def initialize (left_node, right_node)
        super("Unmatched block tag: Left is #{left_node}, but Right is #{right_node}")
      end
    end # }}}
  end # }}}

  module Token # {{{
    class Base
    end

    class Text < Base
      attr_reader :text

      def initialize (text)
        @text = text
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
    end

    class LineBreak < Base; end
    class RubyBar < Base; end
    class RiceMark < Base; end


    class Annotation < Base
      attr_reader :target, :spec, :whole

      def initialize (text)
        @whole = text

        if m = text.match(/^「([^」]+)」[はに](.+)/)
          @target = m[1]
          @spec = m[2]
        end
      end
    end

    class Tokens < Array; end
  end # }}}

  module Tree # {{{
    class Node # {{{
      PROPERTY_NAMES = []

      def self.display_name
        self.name.split(/::/).last
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
        raise Error::Implementation, "It's not Array: #{items}" unless Array === items
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
    class LineBreak < Node; end
    class Ruby < Block # {{{
      attr_reader *(PROPERTY_NAMES = superclass::PROPERTY_NAMES + [:ruby])

      def initialize (items = [], ruby = nil)
        super(items)
        @ruby = ruby
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
  end # }}}

  class Lexer # {{{
    def self.lex (source)
      instance = self.new
      instance.lex(source)
      instance.tokens
    end

    attr_reader :tokens

    def initialize
      @tokens = Token::Tokens.new
    end

    def lex (source)
      source = StringIO.new(source) if String === source
      read_source(source)
    end

    private

    def read_source (source)
      while line = source.gets
        lb = line.chomp!

        read_line(line)

        put(Token::LineBreak) if lb
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
        @tokens << token.new(*args)
      end
    end
  end # }}}

  module Pattern # {{{
    NUMS = /[０-９0-9]/
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
      @text_buffer = ''
      @current_block = @tree
      @block_stack = []
    end

    def parse (source)
      tokens = Lexer.lex(source)

      tokens.each do
        |tok|
        next on_text(tok) if Token::Text === tok

        on_not_text

        case tok
        when Token::LineBreak
          put(Tree::LineBreak)
        when Token::Annotation
          on_annotation(tok)
        end
      end

      on_not_text
    end

    private

    def put (node, *args)
      node = node.new(*args) unless Tree::Node === node
      last = @current_block.last
      if Tree::Text === node and Tree::Text === last
        last.concat(node)
      else
        @current_block << node
      end
      node
    end

    def enter_block (left_node, *args)
      raise Error::NotImplmented

      block = put(left_node, *args)
      raise Error::Implementation, "Not Block: #{block}" unless Tree::Block === block
      @block_stack.push(Stack.new(@current_block, left_node))
      @current_block = block
    end

    def exit_block (right_node)
      raise Error::NotImplmented

      old = @block_stack.pop
      raise Error::UnmatchedBlock.new(old.left_node, right_node) unless old.left_node.class == right_node
      @current_block = old.block
    end

    def on_text (tok)
      @text_buffer += tok.text
    end

    def on_not_text
      return if @text_buffer.empty?
      put(Tree::Text, @text_buffer)
      @text_buffer = ''
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
      end
    end

    def on_annotation_with_no_target (tok)
      raise Error::NotImplmented

      case tok.spec
      when /(?:ここから)?(?:引用文、?)?(#{Pattern::NUMS}+)字下げ(?:、折り返して#{Pattern::NUMS}+字下げ|、本文とはアキナシ)?/
        enter_block(Tree::Top)
      end
    end

    def on_targeted (tok, klass, *args)
      @current_block.replace_last_block do
        |block|
        l, c, r = block.split_by_text(tok.target)
        [*l, klass.new(Tree::Block === c ? c.items : [c], *args), *r]
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
