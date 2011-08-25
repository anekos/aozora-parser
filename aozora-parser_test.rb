#!/usr/bin/ruby
# vim:set fileencoding=cp932 :

require 'minitest/unit'
require 'minitest/autorun'
require 'aozora-parser'

AozoraParser.make_simple_inspect

# Token

class TestTokenAnnotation < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_simple # {{{
    t = Token::Annotation.new('�L�Ȃ�')

    assert_equal '�L�Ȃ�',  t.whole
    assert_equal nil,       t.target
    assert_equal nil,       t.spec
  end # }}}

  def test__with_target # {{{
    t = Token::Annotation.new('�u�L�v�͑���')

    assert_equal '�u�L�v�͑���',  t.whole
    assert_equal '�L',            t.target
    assert_equal '����',          t.spec
  end # }}}

  def test__with_target_invalid # {{{
    t = Token::Annotation.new('���u�L�v�͑���')

    assert_equal '���u�L�v�͑���',  t.whole
    assert_equal nil,               t.target
    assert_equal nil,               t.spec
  end # }}}
end # }}}

class TestLexer < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_line_break # {{{
    ts = Lexer.lex("�������傤��\n�ɂ��傤��")

    assert_equal 3, ts.size
    assert_instance_of Token::Hiragana,   ts[0]
    assert_equal       '�������傤��',    ts[0].text
    assert_instance_of Token::LineBreak,  ts[1]
    assert_instance_of Token::Hiragana,   ts[2]
    assert_equal       '�ɂ��傤��',      ts[2].text
  end # }}}

  def test_text # {{{
    ts = Lexer.lex("�˂��͂��킢��")

    assert 1, ts.size
    assert_instance_of Token::Hiragana,   ts[0]
    assert_equal       '�˂��͂��킢��',  ts[0].text
  end # }}}

  def test_ruby # {{{
    ts = Lexer.lex("�L�s�˂��t")

    assert_equal 2, ts.size
    assert_instance_of Token::Kanji,              ts[0]
    assert_equal       '�L',                      ts[0].text
    assert_instance_of Token::Ruby,               ts[1]
    assert_equal       '�˂�',                    ts[1].ruby
  end # }}}

  def test_ruby__with_bar # {{{
    ts = Lexer.lex("�킽���͂��̂��킢���b�L�s�˂��t���Ȃ߂邱�Ƃ����ł��Ȃ��̂ł�����")

    assert_equal 5, ts.size
    assert_instance_of Token::Hiragana,           ts[0] # �킽���͂��̂��킢��
    assert_equal       '�킽���͂��̂��킢��',    ts[0].text
    assert_instance_of Token::RubyBar,            ts[1] # �b
    assert_instance_of Token::Kanji,              ts[2] # �L
    assert_equal       '�L',                      ts[2].text
    assert_instance_of Token::Ruby,               ts[3] # �s�˂��t
    assert_equal       '�˂�',                    ts[3].ruby
    assert_instance_of Token::Hiragana,           ts[4] # ���Ȃ߂邱�Ƃ����ł��Ȃ��̂ł�����
  end # }}}

  def test_char_type # {{{
    ts = Lexer.lex("���̓l�R���r�߂�")

    assert_equal 6, ts.size
    assert_instance_of Token::Kanji,       ts[0] # ��
    assert_instance_of Token::Hiragana,    ts[1] # ��
    assert_instance_of Token::Katakana,    ts[2] # �l�R
    assert_instance_of Token::Hiragana,    ts[3] # ��
    assert_instance_of Token::Kanji,       ts[4] # �r
    assert_instance_of Token::Hiragana,    ts[5] # �߂�
  end # }}}

  def test_marks # {{{
    ts = Lexer.lex("foo�b��bar")

    assert_equal 4, ts.size
    assert_instance_of Token::OtherText,              ts[0]
    assert_equal      'foo',                          ts[0].text
    assert_instance_of Token::RubyBar,                ts[1]
    assert_instance_of Token::RiceMark,               ts[2]
    assert_instance_of Token::OtherText,              ts[3]
    assert_equal      'bar',                          ts[3].text
  end # }}}
end # }}}

# Parser

class TestTreeNode < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_equivalent # {{{
    assert_block { Tree::Text.new('�ق�') == Tree::Text.new('�ق�') }
    assert_block { not Tree::Text.new('�ق�') == Tree::Text.new('����') }
    assert_block { not Tree::Text.new('�ق�') == Tree::Ruby.new([Tree::Text.new('�ق�')]) }
    assert_block { Tree::Text.new('�ق�').text == Tree::Ruby.new([Tree::Text.new('�ق�')]).text }

    assert_block { Tree::LineBreak.new == Tree::LineBreak.new }
    assert_block { Tree::Bold.new([Tree::Text.new('a')]) == Tree::Bold.new([Tree::Text.new('a')]) }
    assert_block { Tree::Bottom.new([Tree::Text.new('a')]) == Tree::Bottom.new([Tree::Text.new('a')]) }
    assert_block { Tree::Top.new([Tree::Text.new('a')]) == Tree::Top.new([Tree::Text.new('a')]) }

    assert_block { not Tree::Bold.new([Tree::Text.new('a')]) == Tree::Bold.new([Tree::Text.new('A')]) }
    assert_block { not Tree::Bottom.new([Tree::Text.new('a')]) == Tree::Bottom.new([Tree::Text.new('A')]) }
    assert_block { not Tree::Top.new([Tree::Text.new('a')]) == Tree::Top.new([Tree::Text.new('A')]) }
  end # }}}

  def test_display_name # {{{
    assert_equal 'Text',      Tree::Text.display_name
    assert_equal 'Ruby',      Tree::Ruby.display_name
    assert_equal 'Document',  Tree::Document.display_name
    assert_equal 'Bold',      Tree::Bold.display_name
  end # }}}
end # }}}

class TestTreeBlock < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_text # {{{
    t =
      Tree::Block.new([
        Tree::Text.new('a'),
        Tree::LineBreak.new,
        Tree::Text.new('b'),
        Tree::Ruby.new([
          Tree::Text.new('c'),
          Tree::Text.new('d')
        ]),
        Tree::Text.new('e')
      ])

    assert_equal 'abcde',    t.text
  end # }}}

  def test_last_block_range__with_linebreak # {{{
    ts = [
      t0 = Tree::Text.new('a'),
      t1 = Tree::LineBreak.new,
      t2 = Tree::Text.new('c'),
      t3 = Tree::LineBreak.new,
      t4 = Tree::Text.new('e'),
      t5 = Tree::Ruby.new([Tree::Text.new('f1'), Tree::Text.new('f2')]),
      t6 = Tree::Text.new('g'),
    ]

    range = Tree::Block.new(ts).last_block_range

    assert_equal (4 .. 6),  range
  end # }}}

  def test_last_block_range__with_no_linebreak # {{{
    ts = [
      t0 = Tree::Text.new('a'),
      t1 = Tree::Text.new('b'),
      t2 = Tree::Ruby.new([Tree::Text.new('c1'), Tree::Text.new('c2')]),
      t3 = Tree::Text.new('d'),
    ]

    range = Tree::Block.new(ts).last_block_range

    assert_equal   (0 .. 3),  range
  end # }}}

  def test_last_block_range__with_inner_linebreak # {{{
    ts = [
      t0 = Tree::Text.new('a'),
      t1 = Tree::Text.new('b'),
      t2 = Tree::Ruby.new([Tree::Text.new('c1'), Tree::LineBreak.new, Tree::Text.new('c2')]),
      t3 = Tree::Text.new('d'),
    ]

    range = Tree::Block.new(ts).last_block_range

    assert_equal  (0 .. 3),   range
  end # }}}

  def test_replace_last_block # {{{
    ts = [
      t0 = Tree::Text.new('a'),
      t1 = Tree::LineBreak.new,
      t2 = Tree::Text.new('c'),
      t3 = Tree::LineBreak.new,
      t4 = Tree::Text.new('e'),
      t5 = Tree::Ruby.new([Tree::Text.new('f1'), Tree::Text.new('f2')]),
      t6 = Tree::Text.new('g'),
    ]

    nt1 = Tree::Text.new('aa')
    nt2 = Tree::Text.new('bb')

    b = Tree::Block.new(ts)

    b.replace_last_block do
      |block|
      return [nt1, nt2]
    end

    assert_equal 5,     b.size
    assert_equal nt1,   b[4]
    assert_equal nt2,   b[5]
  end # }}}

  def test_replace_last_block__with_block_instance # {{{
    ts = [
      t0 = Tree::Text.new('a'),
      t1 = Tree::LineBreak.new,
      t2 = Tree::Text.new('c'),
      t3 = Tree::LineBreak.new,
      t4 = Tree::Text.new('e'),
      t5 = Tree::Ruby.new([Tree::Text.new('f1'), Tree::Text.new('f2')]),
      t6 = Tree::Text.new('g'),
    ]

    nt1 = Tree::Text.new('aa')
    nt2 = Tree::Text.new('bb')

    b = Tree::Block.new(ts)

    b.replace_last_block do
      |block|
      return Tree::Block.new([nt1, nt2])
    end

    assert_equal 5,     b.size
    assert_equal nt1,   b[4]
    assert_equal nt2,   b[5]
  end # }}}

  def test_split # {{{
    # XXX �P�Ȃ�e�L�X�g�ɕ��������ꍇ�́ABlock �Ȃǂɂ���Ȃ��ŕԂ�

    l, r =
      Tree::Block.new([
        Tree::Ruby.new([Tree::Text.new('�Z��')]),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(3)

    assert_equal Tree::Block.new([Tree::Ruby.new([Tree::Text.new('�Z��')]), Tree::Text.new('��')]),
                                                      l
    assert_equal Tree::Text.new('�O�l�ܘZ������'),    r
  end # }}}

  def test_split__simple # {{{
    # XXX �P�Ȃ�e�L�X�g�ɕ��������ꍇ�́ABlock �Ȃǂɂ���Ȃ��ŕԂ�

    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(3)

    assert_equal Tree::Text.new('�Z���'),            l
    assert_equal Tree::Text.new('�O�l�ܘZ������'),    r
  end # }}}

  def test_split__empty # {{{
    # XXX ����ɂȂ�ꍇ�� nil

    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(0)

    assert_equal nil,                                       l
    assert_equal Tree::Text.new('�Z���O�l�ܘZ������'),    r


    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(10)

    assert_equal Tree::Text.new('�Z���O�l�ܘZ������'),    l
    assert_equal nil,                                       r


    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(11)

    assert_equal Tree::Text.new('�Z���O�l�ܘZ������'),    l
    assert_equal nil,                                       r


    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(9)

    assert_equal Tree::Text.new('�Z���O�l�ܘZ����'),    l
    assert_equal Tree::Text.new('��'),                    r
  end # }}}

  def test_split_by_text # {{{
    # XXX �e�L�X�g���A������ꍇ�́A�A������

    l, c, r =
      Tree::Block.new([
        Tree::Ruby.new([
          Tree::Text.new('�Z��')
        ]),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split_by_text('�O�l��')

    assert_equal Tree::Block.new([Tree::Ruby.new([Tree::Text.new('�Z��')]), Tree::Text.new('��')]),
                                                  l
    assert_equal Tree::Text.new('�O�l��'),        c
    assert_equal Tree::Text.new('�Z������'),      r
  end # }}}

  def test_split_by_text__simple # {{{
    # XXX �P�Ȃ�e�L�X�g�ɕ��������ꍇ�́ABlock �Ȃǂɂ���Ȃ��ŕԂ�

    l, c, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split_by_text('��O�l')

    assert_equal Tree::Text.new('�Z��'),        l
    assert_equal Tree::Text.new('��O�l'),      c
    assert_equal Tree::Text.new('�ܘZ������'),  r
  end # }}}
end # }}}

class TestTreeLeveled < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_new # {{{
    t = Tree::Leveled.new([], '3')
    assert_equal 3,                         t.level
    assert_equal Tree::Leveled.new([], 3),  t

    t = Tree::Leveled.new([])
    assert_equal nil,                         t.level
    assert_equal Tree::Leveled.new([], nil),  t
  end # }}}
end # }}}

class TestTreeText < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_text # {{{
    t = Tree::Text.new('�˂���񂿂�')

    assert_equal '�˂���񂿂�',    t.text
  end # }}}

  def test_split # {{{
    l, r = Tree::Text.new('�Z���O�l�ܘZ������').split(4)
    assert_equal Tree::Text.new('�Z���O'),      l
    assert_equal Tree::Text.new('�l�ܘZ������'),  r

    l, r = Tree::Text.new('�Z���O�l�ܘZ������').split(10)
    assert_equal Tree::Text.new('�Z���O�l�ܘZ������'),    l
    assert_equal nil,                                       r

    l, r = Tree::Text.new('�Z���O�l�ܘZ������').split(1)
    assert_equal Tree::Text.new('�Z'),                    l
    assert_equal Tree::Text.new('���O�l�ܘZ������'),    r

    l, r = Tree::Text.new('�Z���O�l�ܘZ������').split(0)
    assert_equal nil,                                       l
    assert_equal Tree::Text.new('�Z���O�l�ܘZ������'),    r
  end # }}}

  def test_split_by_text # {{{
    # XXX ������̒�������ɂȂ�ꍇ�́Anil ��Ԃ��ȗ�����

    # �^��
    l, c, r = Tree::Text.new('�Z���O�l�ܘZ������').split_by_text('�O�l��')

    assert_equal Tree::Text.new('�Z���'),    l
    assert_equal Tree::Text.new('�O�l��'),    c
    assert_equal Tree::Text.new('�Z������'),  r

    # �����
    l, c, r = Tree::Text.new('�Z���O�l�ܘZ������').split_by_text('�Z���')

    assert_equal nil,                               l
    assert_equal Tree::Text.new('�Z���'),          c
    assert_equal Tree::Text.new('�O�l�ܘZ������'),  r

    # �E���
    l, c, r = Tree::Text.new('�Z���O�l�ܘZ������').split_by_text('������')

    assert_equal Tree::Text.new('�Z���O�l�ܘZ'),  l
    assert_equal Tree::Text.new('������'),          c
    assert_equal nil,                               r
  end # }}}
end # }}}

class TestTreeRuby < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_text # {{{
    t =
      Tree::Ruby.new([
        Tree::Text.new('�Z���'),
        Tree::Text.new('�O�l�ܘZ������')
      ])

    assert_equal '�Z���O�l�ܘZ������',    t.text
  end # }}}
end # }}}

class TestParser < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_simple_text # {{{
    ts = Parser.parse('�˂����r�߂���')

    assert_equal 1, ts.size
    assert_instance_of Tree::Text, ts[0]
  end # }}}

  def test_three_lines # {{{
    ts = Parser.parse <<EOT
�l�R�r��
��abc��
�݂�
EOT

    assert_equal 6, ts.size
    assert_instance_of Tree::Text,      ts[0]
    assert_equal       '�l�R�r��',      ts[0].text
    assert_instance_of Tree::LineBreak, ts[1]
    assert_instance_of Tree::Text,      ts[2]
    assert_equal       '��abc��',       ts[2].text
    assert_instance_of Tree::LineBreak, ts[3]
    assert_instance_of Tree::Text,      ts[4]
    assert_equal       '�݂�',          ts[4].text
    assert_instance_of Tree::LineBreak, ts[5]
  end # }}}

  def test_bold_near # {{{
    ts = Parser.parse("�����̂Ƃ���͂˂��m���u�˂��v�͑����n���Ȃ߂���")

    assert_equal 3, ts.size
    assert_instance_of Tree::Text,              ts[0]
    assert_instance_of Tree::Bold,              ts[1]
    assert_instance_of Tree::Text,              ts[2]
    assert_equal       '���Ȃ߂���',            ts[2].text

    bold = ts[1]
    assert_equal 1, bold.size
    assert_instance_of Tree::Text,  bold[0]
    assert_equal       '�˂�',      bold.text
    assert_equal       '�˂�',      bold[0].text
  end # }}}

  def test_dots # {{{
    ts = Parser.parse("�����̂Ƃ���͂˂����m���u�˂��v�ɖT�_�n�Ȃ߂���")

    assert_equal 3, ts.size
    assert_instance_of Tree::Text,              ts[0]
    assert_instance_of Tree::Dots,              ts[1]
    assert_instance_of Tree::Text,              ts[2]
    assert_equal       '���Ȃ߂���',            ts[2].text

    dots = ts[1]
    assert_equal 1, dots.size
    assert_instance_of Tree::Text,  dots[0]
    assert_equal       '�˂�',      dots.text
    assert_equal       '�˂�',      dots[0].text
  end # }}}

  def test_dots_multi_line # {{{
    ts = Parser.parse("���͂悤�I\n�Ȃ����˂����m���u�˂��v�ɖT�_�n�Ȃ߂�����")

    assert_equal 5, ts.size
    assert_equal Tree::Text.new('���͂悤�I'),              ts[0]
    assert_equal Tree::LineBreak.new,                       ts[1]
    assert_equal Tree::Text.new('�Ȃ���'),                  ts[2]
    assert_equal Tree::Dots.new([Tree::Text.new('�˂�')]),  ts[3]
    assert_equal Tree::Text.new('���Ȃ߂�����'),            ts[4]

    dots = ts[3]
    assert_equal 1, dots.size
    assert_instance_of Tree::Text,  dots[0]
    assert_equal       '�˂�',      dots.text
    assert_equal       '�˂�',      dots[0].text
  end # }}}

  def test_dots_near # {{{
    ts = Parser.parse("�����̂Ƃ���͂˂��m���u�˂��v�ɖT�_�n���Ȃ߂���")

    assert_equal 3, ts.size
    assert_instance_of Tree::Text,              ts[0]
    assert_instance_of Tree::Dots,              ts[1]
    assert_instance_of Tree::Text,              ts[2]
    assert_equal       '���Ȃ߂���',            ts[2].text

    dots = ts[1]
    assert_equal 1, dots.size
    assert_instance_of Tree::Text,  dots[0]
    assert_equal       '�˂�',      dots.text
    assert_equal       '�˂�',      dots[0].text
  end # }}}

  def test_heading # {{{
    ts = Parser.parse("meow\n�F���L�m���u�F���L�v�͒����o���n\nmeow")

    assert_equal 5, ts.size
    assert_equal Tree::Text.new('meow'),                                ts[0]
    assert_equal Tree::LineBreak.new,                                   ts[1]
    assert_equal Tree::Heading.new([Tree::Text.new('�F���L')], '��'),   ts[2]
    assert_equal Tree::LineBreak.new,                                   ts[3]
    assert_equal Tree::Text.new('meow'),                                ts[4]
  end # }}}

  def test_top # {{{
    # XXX ���s�������ʒu�ɂ��イ��
    # See: http://kumihan.aozora.gr.jp/layout2.html#jisage
    ts = Parser.parse <<EOT
Hello
�m����������R�������n
�˂�
�Ȃ�
�m�������Ŏ������I���n
World
EOT

    except =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('�˂�'),
              Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'),
              Tree::LineBreak.new
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal except, ts
  end # }}}

  def test_block_annotation # {{{
    # XXX ���s�������ʒu�ɂ��イ��
    # See: http://kumihan.aozora.gr.jp/layout2.html#jisage

    ts = Parser.parse <<EOT
Hello
�m����������R�������n
�˂�
�Ȃ�
�m�������Ŏ������I���n
World
EOT

    except =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('�˂�'),
              Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'),
              Tree::LineBreak.new
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal except, ts
  end # }}}

  def test_continued_block_annotation # {{{
    # XXX �A������ꍇ�́A�r���̏I���^�O���ȗ��ł���
    # See: http://kumihan.aozora.gr.jp/layout2.html#jisage

    ts = Parser.parse <<EOT
�m����������Q�������n
one
�m����������S�������n
two
three
�m�������Ŏ������I���n
four
EOT

    except =
      Tree::Document.new(
        [
          Tree::Top.new(
            [
              Tree::Text.new('one'),
              Tree::LineBreak.new,
            ],
            2
          ),
          Tree::Top.new(
            [
              Tree::Text.new('two'),
              Tree::LineBreak.new,
              Tree::Text.new('three'),
              Tree::LineBreak.new
            ],
            4
          ),
          Tree::Text.new('four'),
          Tree::LineBreak.new
        ]
      )
    assert_equal except, ts

  end # }}}

  def test_umnatched_block_annotation # {{{
    assert_raises(Error::UnmatchedBlock) do
      ts = Parser.parse <<EOT
Hello
�m����������R�������n
�˂�
�Ȃ�
�m�������Œn�t���I���n
World
EOT
    end
  end # }}}

  def test_no_block_end # {{{
    assert_raises(Error::NoBlockEnd) do
      ts = Parser.parse <<EOT
Hello
�m����������R�������n
�˂�
�Ȃ�
EOT
    end

    assert_raises(Error::NoBlockEnd) do
      ts = Parser.parse <<EOT
Hello
�m����������R�������n
�˂�
�Ȃ�
�m����������n�t���n
�m�������Œn�t���I���n
EOT
    end

    ts = Parser.parse <<EOT
Hello
�m����������R�������n
one
�L�m���u�L�v�͑����n
two
�m�������Ŏ������I���n
EOT
    except =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('one'),
              Tree::LineBreak.new,
              Tree::Bold.new([Tree::Text.new('�L')]),
              Tree::LineBreak.new,
              Tree::Text.new('two'),
              Tree::LineBreak.new
            ],
            3
          )
        ]
      )
    assert_equal except, ts
  end # }}}
end # }}}

# make_simple_inspect

class TestSimpleInspect < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_pretty_print
    node = Tree::Text.new('neko')
    assert_equal <<EOT, node.inspect

#<TText text="neko">
EOT

    node = Tree::Bold.new([Tree::Text.new('neko')])
    assert_equal <<EOT, node.inspect

#<TBold items=[#<TText text="neko">]>
EOT

    node = Tree::Ruby.new([Tree::Text.new('neko')], 'motz')
    assert_equal <<EOT, node.inspect

#<TRuby items=[#<TText text="neko">] ruby="motz">
EOT

    node = Tree::Leveled.new([Tree::Text.new('neko')], 3)
    assert_equal <<EOT, node.inspect

#<TLeveled items=[#<TText text="neko">] level=3>
EOT
  end
end # }}}
