#!/usr/bin/ruby
# vim:set fileencoding=CP932 :

require 'minitest/unit'
require 'minitest/autorun'
require 'aozora-parser'

Encoding.default_external = 'Shift_JIS'
STDOUT.set_encoding('UTF-8')

AozoraParser.make_simple_inspect

module MiniTest::Assertions # {{{
  def assert_not_equal (expected, actual, message = nil)
    assert(
      expected != actual,
      message || "Both values equal to #{expected}."
    )
  end

  def assert_not_same (expected, actual, message = nil)
    assert(
      expected.object_id != actual.object_id,
      message || "Both values are same to #{expected}."
    )
  end

  def assert_not_raise (message = nil, &block)
    e = nil
    begin
      block.call
    rescue Exception => e
    end
    assert(!e, message || "Block raises #{e}")
  end
end # }}}

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

  def test_line_number # {{{
    ts = Lexer.lex <<-EOT
hoge
moge
mige
EOT
    assert_equal 1, ts[0].line
    assert_equal 1, ts[1].line
    assert_equal 2, ts[2].line
    assert_equal 2, ts[3].line
    assert_equal 3, ts[4].line
    assert_equal 3, ts[5].line

    ts = Lexer.lex <<-EOT
�����̂Ƃ���͂˂��m���u�˂��v�ɖT�_�n���Ȃ߂���
moge
mige
EOT
    assert_equal 3, ts.last.line
  end # }}}

  def test_aozora_notes # {{{
    ts = Lexer.lex <<-EOT
first line
second line
third line
forth line
EOT
    assert_equal 8,  ts.size

    ts = Lexer.lex <<-EOT
first line
second line
-------------------------------------------------------
�y�e�L�X�g���Ɍ����L���ɂ��āz

�s�t�F���r
�i��j�����s������t

�m���n�F���͎Ғ��@��ɊO���̐�����A�T�_�̈ʒu�̎w��
�@�@�@�i�����́AJIS X 0213�̖ʋ�_�ԍ��A�܂��͒�{�̃y�[�W�ƍs���j
�i��j2�m���u2�v�̓��[�}�����A1-13-22�n
-------------------------------------------------------
third line
forth line
EOT
    assert_equal          'first line',       ts[0].text
    assert_instance_of    Token::LineBreak,   ts[1]
    assert_equal          'forth line',       ts[6].text
    assert_equal          8,                  ts.size
  end # }}}

  def test_image_tag_line # {{{
    ts = Lexer.lex <<-EOT
first line
second line
<img src="img/00.jpg">
third line
EOT
    assert_equal          7,                                ts.size
    assert_equal          'first line',                     ts[0].text
    assert_equal          Token::Image.new('img/00.jpg'),   ts[4]
    assert_equal          'third line',                     ts[5].text
  end # }}}

  def test_nested # {{{
    ts = Lexer.lex(<<EOT)
�Ђ��m���u�Ђ��v�ɖT�_�n�O���ām���u�Ђ��m���u�Ђ��v�ɖT�_�n�O���āv�͒�{�ł́u�Ђ��O�m���u���O�v�ɖT�_�n���āv�n�E��
EOT
    expected =
      [
        Token::Hiragana.new('�Ђ�'),
        Token::Annotation.new('�u�Ђ��v�ɖT�_'),
        Token::Kanji.new('�O'),
        Token::Hiragana.new('����'),
        Token::Annotation.new('�u�Ђ��m���u�Ђ��v�ɖT�_�n�O���āv�͒�{�ł́u�Ђ��O�m���u���O�v�ɖT�_�n���āv'),
        Token::Kanji.new('�E'),
        Token::Hiragana.new('��'),
        Token::LineBreak.new
      ]
    assert_equal expected, ts
  end # }}}

  def test_ignore_bottom_info # {{{
    ts = Parser.parse <<-EOT
�ق�Ԃ�1
�ق�Ԃ�2
�ق�Ԃ�3
��{�F�u������{�v�z��n�@14�@�|�p�̎v�z�v�}�����[
�@�@�@1964�i���a39�j�N8��15�����s
���́F�y����
�Z���F���엲�r
2008�N1��25���쐬
�󕶌ɍ쐬�t�@�C���F
���̃t�@�C���́A�C���^�[�l�b�g�̐}���فA�󕶌Ɂihttp://www.aozora.gr.jp/�j�ō���܂����B���́A�Z���A����ɂ��������̂́A�{�����e�B�A�̊F����ł��B
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('�ق�Ԃ�1'),
          Tree::LineBreak.new,
          Tree::Text.new('�ق�Ԃ�2'),
          Tree::LineBreak.new,
          Tree::Text.new('�ق�Ԃ�3'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
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
    assert_block { Tree::Top.new([Tree::Text.new('a')], 10) == Tree::Top.new([Tree::Text.new('a')], 10) }

    assert_block { not Tree::Bold.new([Tree::Text.new('a')]) == Tree::Bold.new([Tree::Text.new('A')]) }
    assert_block { not Tree::Bottom.new([Tree::Text.new('a')]) == Tree::Bottom.new([Tree::Text.new('A')]) }
    assert_block { not Tree::Top.new([Tree::Text.new('a')]) == Tree::Top.new([Tree::Text.new('A')]) }
    assert_block { not Tree::Top.new([Tree::Text.new('a')], 3) == Tree::Top.new([Tree::Text.new('A')], 2) }
  end # }}}

  def test_initialize_copy # {{{
    a = Tree::Text.new('hoge')
    b = a.clone
    assert_not_same a.text, b.text

    a = Tree::Block.new([Tree::Text.new('hoge')])
    b = a.clone
    assert_not_same a.items, b.items
    assert_not_same a.items.first, b.items.first
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
    # �������ꂽ���̂́A���̃R���e�i�ɓ����Ă���

    l, r =
      Tree::Block.new([
        Tree::Ruby.new([Tree::Text.new('�Z��')]),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(3)
    assert_equal Tree::Block.new([Tree::Ruby.new([Tree::Text.new('�Z��')]), Tree::Text.new('��')]), l
    assert_equal Tree::Block.new([Tree::Text.new('�O�l�ܘZ������')]),                               r

    l, r =
      Tree::Block.new([
        Tree::Bold.new([Tree::Text.new('�Z��')]),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(3)

    assert_equal Tree::Block.new([
                  Tree::Bold.new([Tree::Text.new('�Z��')]),
                  Tree::Text.new('��')
                 ]),  l
    assert_equal Tree::Block.new([Tree::Text.new('�O�l�ܘZ������')]), r

    l, r =
      Tree::Block.new([
        Tree::Bold.new([Tree::Text.new('�Z��')]),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(2)
    assert_equal Tree::Block.new([
                  Tree::Bold.new([Tree::Text.new('�Z��')]),
                 ]),  l
    assert_equal Tree::Block.new([Tree::Text.new('��O�l�ܘZ������')]), r
  end # }}}

  def test_split__simple # {{{
    # �������ꂽ���̂́A���̃R���e�i�ɓ����Ă���

    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(3)

    assert_equal Tree::Block.new([Tree::Text.new('�Z���')]),            l
    assert_equal Tree::Block.new([Tree::Text.new('�O�l�ܘZ������')]),    r

    l, r =
      Tree::Bold.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(3)

    assert_equal Tree::Bold.new([Tree::Text.new('�Z���')]),            l
    assert_equal Tree::Bold.new([Tree::Text.new('�O�l�ܘZ������')]),    r
  end # }}}

  def test_split__empty # {{{
    # XXX ��ɂȂ�ꍇ�� nil

    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(0)

    assert_equal nil,                                                         l
    assert_equal Tree::Block.new([Tree::Text.new('�Z���O�l�ܘZ������')]),   r


    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(10)

    assert_equal Tree::Block.new([Tree::Text.new('�Z���O�l�ܘZ������')]),   l
    assert_equal nil,                                                         r


    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(11)

    assert_equal Tree::Block.new([Tree::Text.new('�Z���O�l�ܘZ������')]),   l
    assert_equal nil,                                                         r


    l, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split(9)

    assert_equal Tree::Block.new([Tree::Text.new('�Z���O�l�ܘZ����')]),    l
    assert_equal Tree::Block.new([Tree::Text.new('��')]),                    r
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
    assert_equal Tree::Block.new([Tree::Text.new('�O�l��')]),        c
    assert_equal Tree::Block.new([Tree::Text.new('�Z������')]),      r


    l, c, r =
      Tree::Document.new([
        Tree::Text.new('HEAD'),
        Tree::Ruby.new([Tree::Text.new('��O�l')], '���r'),
        Tree::Text.new('TAIL'),
      ]).split_by_text('��O�l')
    assert_equal Tree::Document.new([Tree::Text.new('HEAD')]), l


    # ���r(�u���b�N)�𕪊����邱�Ƃ͂ł��Ȃ�
    ruby = Tree::Ruby.new([Tree::Text.new('foobarbaz')], '���^�\���ϐ�')
    assert_raises(Error::SplitBlockByForwardRef) do
      ruby.split_by_text('bar')
    end
  end # }}}

  def test_split_by_text__simple # {{{
    l, c, r =
      Tree::Block.new([
        Tree::Text.new('�Z��'),
        Tree::Text.new('��O�l'),
        Tree::Text.new('�ܘZ������'),
      ]).split_by_text('��O�l')

    assert_equal Tree::Block.new([Tree::Text.new('�Z��')]),        l
    assert_equal Tree::Block.new([Tree::Text.new('��O�l')]),      c
    assert_equal Tree::Block.new([Tree::Text.new('�ܘZ������')]),  r
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

class TestTreeJIS < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_new # {{{
    t = Tree::JIS.new([Tree::Text.new('foo')], '�u�M�{�d�v�A��4����2-12-11')
    assert_equal [2, 12, 11],     t.char.code
    assert_equal 4,               t.char.level
    assert_equal ['�M', '�d'],    t.char.parts

    t = Tree::JIS.new([Tree::Text.new('foo')], '�u�M�{�d�v�A��l����2-12-11')
    assert_equal 4,               t.char.level

    t = Tree::JIS.new([Tree::Text.new('foo')], '�u�M�{�d�v�A��S����2-12-11')
    assert_equal 4,               t.char.level
  end # }}}
end # }}}

class TestTreeUnicode < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_new # {{{
    t = Tree::Unicode.new([Tree::Text.new('��')], '�u������ւ�{�Ɂv�Aunicode8932')
    assert_equal [Tree::Text.new('��')],  t.items
    assert_equal 0x8932,                  t.char.code
    assert_equal ['������ւ�', '��'],    t.char.parts
  end # }}}
end # }}}

class TestTreeChar < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_jis # {{{
    c = Char::JIS.parse('�u�M�{�d�v�A��4����2-12-11')
    assert_equal 4,             c.level
    assert_equal [2, 12, 11],   c.code
    assert_equal ['�M', '�d'],  c.parts

    c = Char::JIS.parse('�u�˂��݂݁{�d�v�A��4����2-12-11')
    assert_equal 4,                   c.level
    assert_equal [2, 12, 11],         c.code
    assert_equal ['�˂��݂�', '�d'],  c.parts

    assert_raises(Error::Format) { Char::JIS.parse('�u�M�{�d�v�A��4����2+12+11') }
  end # }}}

  def test_unicode # {{{
    c = Char::Unicode.parse('�u������ւ�{�Ɂv�Aunicode8932')
    assert_equal 0x8932,                c.code
    assert_equal ['������ւ�', '��'],  c.parts

    assert_raises(Error::Format) { p Char::Unicode.parse('�u������ւ�{�Ɂv�Aunicode89x2').code }
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

  def test_target_annotation # {{{
    ts = Parser.parse("�����̂Ƃ���͂˂����m���u�˂��v�ɖT�_�n�Ȃ߂���")

    assert_equal 3, ts.size
    assert_instance_of Tree::Text,              ts[0]
    assert_instance_of Tree::Text,              ts[2]
    assert_equal       '���Ȃ߂���',            ts[2].text

    inner = [Tree::Text.new('�˂�')]

    assert_equal Tree::Dots.new(inner),   ts[1]

    ts = Parser.parse("�����̂Ƃ���͂˂����m���u�˂��v�͏c�����n�Ȃ߂���")
    assert_equal Tree::Yoko.new(inner),   ts[1]

    ts = Parser.parse("�����̂Ƃ���͂˂����m���u�˂��v�͑����n�Ȃ߂���")
    assert_equal Tree::Bold.new(inner),   ts[1]

    ts = Parser.parse("�����̂Ƃ���͂˂����m���u�˂��v�͖T���n�Ȃ߂���")
    assert_equal Tree::Line.new(inner),   ts[1]
  end # }}}

  def test_unkown # {{{
    ts = Parser.parse <<EOT
Hello
�m�������イ���I����͂����イ���I�n
World
EOT

    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Unknown.new(Token::Annotation.new('�����イ���I����͂����イ���I')),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts


    ts = Parser.parse <<EOT
Hello
�˂��m���u�˂��v�͂����イ���n
World
EOT

    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('�˂�'),
          Tree::Unknown.new(Token::Annotation.new('�u�˂��v�͂����イ��')),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  def test_rice_mark # {{{
    # XXX ���͓��ɉ����Ȃ���΁A���̂܂܏o�͂���

    ts = Parser.parse <<EOT
Hello
���́�����D���ł��B
World
EOT

    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('���́�����D���ł��B'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  def test_rice_mark_with_annotation # {{{
    ts = Parser.parse <<EOT
Hello
���́b���������m���˂��n����D���ł��B
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('����'),
          Tree::Note.new([Tree::Text.new('��������')], '�˂�'),
          Tree::Text.new('����D���ł��B'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    ts = Parser.parse <<EOT
Hello
���́b���m���˂��n����D���ł��B
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('����'),
          Tree::Note.new([Tree::Text.new('��')], '�˂�'),
          Tree::Text.new('����D���ł��B'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    ts = Parser.parse <<EOT
Hello
���́��������m���˂��n����D���ł��B
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('����'),
          Tree::Note.new([Tree::Text.new('��������')], '�˂�'),
          Tree::Text.new('����D���ł��B'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    ts = Parser.parse <<EOT
Hello
���́��m���˂��n����D���ł��B
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('����'),
          Tree::Note.new([Tree::Text.new('��')], '�˂�'),
          Tree::Text.new('����D���ł��B'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
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

    expected =
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
    assert_equal expected, ts
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

    expected =
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
    assert_equal expected, ts

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
    # XXX �f�t�H���g�ł́A�G���[�`�F�b�N���Ȃ�
    ts = Parser.parse(<<EOT)
Hello
�m����������R�������n
�˂�
�Ȃ�
EOT

    assert_raises(Error::NoBlockEnd) do
      opt = ParserOption.new(:check_last_block_end => true)
      ts = Parser.parse(<<EOT, opt)
Hello
�m����������R�������n
�˂�
�Ȃ�
EOT
    end

    # �Ō�̃u���b�N�͕��Ă���̂��A�Ⴄ��ނ̃u���b�N�������Ă���̂ŃG���[
    assert_raises(Error::NoBlockEnd) do
      opt = ParserOption.new(:check_last_block_end => true)
      ts = Parser.parse(<<EOT, opt)
Hello
�m����������R�������n
�˂�
�Ȃ�
�m����������n�t���n
�m�������Œn�t���I���n
EOT
    end

    # ������ނ̃u���b�N�ŘA�����Ă���̂ŃG���[�ɂȂ�Ȃ�
    ts = Parser.parse <<EOT
Hello
�m����������R�������n
�˂�
�Ȃ�
�m����������T�������n
��񂿂�
�m�������Ŏ������I���n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'), Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('�˂�'), Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'), Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Top.new(
            [
              Tree::Text.new('��񂿂�'), Tree::LineBreak.new,
            ],
            5
          ),
        ]
      )
    assert_equal expected, ts

    # ������ނ̃u���b�N�ŘA�����Ă���̂ŃG���[�ɂȂ�Ȃ�
    # �S�������N���X�ł͂Ȃ����A�T�u�N���X <-> �X�[�p�[�N���X�̊֌W
    ts = Parser.parse <<EOT
Hello
�m������������s�V�t���A�܂�Ԃ��ĂP�������n
�˂�
�Ȃ�
�m����������T�������n
��񂿂�
�m�������Ŏ������I���n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'), Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('�˂�'), Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'), Tree::LineBreak.new,
            ],
            nil,
            1
          ),
          Tree::Top.new(
            [
              Tree::Text.new('��񂿂�'), Tree::LineBreak.new,
            ],
            5
          ),
        ]
      )
    assert_equal expected, ts

    begin
      ts = Parser.parse <<EOT
Hello
�m����������R�������n
�Ȃ�
�m����������n�t���n
�m�������Œn�t���I���n
EOT
    rescue => e
      assert_instance_of Error::NoBlockEnd,   e
      assert_instance_of Tree::Top,           e.node
    end

    ts = Parser.parse <<EOT
Hello
�m����������R�������n
one
�L�m���u�L�v�͑����n
two
�m�������Ŏ������I���n
EOT
    expected =
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
    assert_equal expected, ts
  end # }}}

  def test_line_number # {{{
    # TODO ���m�łȂ��ꍇ�����肻��

    ts = Parser.parse <<-EOT
����������
����������
����������
EOT
    assert_equal 1, ts[0].token.line
    assert_equal 3, ts[5].token.line

    ts = Parser.parse <<-EOT
����������
����������
�m����������R�������n
�m�������Ŏ������I���n
EOT
    assert_equal        1,                      ts[0].token.line
    assert_equal        Tree::LineBreak.new,    ts[3]
    assert_instance_of  Tree::Top,              ts[4]
    assert_equal        3,                      ts[4].token.line

    ts = Parser.parse <<-EOT
�˂��m���u�˂��v�ɖT�_�n
EOT
    assert_instance_of  Tree::Dots,   ts[0]
    assert_equal        1,            ts[0].token.line
  end # }}}

  def test_continued_top
    assert_not_raise do
      ts = Parser.parse <<EOT
�m���V����P�V�������n���A����c�c�c�c�c8.�kkammaka_ri_ ca bhariya_ ca�l�i�kkarmaka_ri_ ca dhaja_hata�l�m��t�͉��h�b�g�t���n�j
�m���V����P�V�������n��A�����w�c�c�c�c9.�kdhaja-hrita_�l�m��r�͉��h�b�g�t���n�i�kdhvaja-hrita_�l�m��r�͉��h�b�g�t���n�j
�m���V����Q�U�������n10.�kmuhuttika_�l�i�ktamkhanika_�l�m��m�͏�h�b�g�t���Bn�͉��h�b�g�t���n�j�i�ktatksanika_�l�m��s�͉��h�b�g�t���n�j
EOT
    end
  end
end # }}}

class TestParserOption < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_init__with_block__no_method # {{{
    assert_raises(NameError) do
      ParserOption.new(:hoge => true)
    end
  end # }}}

  def test_init__with_block # {{{
    opt = ParserOption.new(:check_last_block_end => true)

    assert_equal true, opt.check_last_block_end
  end # }}}
end # }}}

# �󕶌ɒ��L�d�l

class TestAozoraSpec < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  # �y�[�W��i�����炽�߂鏈�� {{{
  # http://kumihan.aozora.gr.jp/layout1.html

  # ���� {{{
  def test_layout1_kaicho
    ts = Parser.parse(<<EOT)
�m�������n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::SheetBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # ���y�[�W {{{
  def test_layout1_kaipage
    ts = Parser.parse(<<EOT)
�m�����y�[�W�n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::PageBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # ���i {{{
  def test_layout1_kaidan
    ts = Parser.parse(<<EOT)
�m�����i�n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::ParagraphBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # }}}

  # ������ {{{
  # http://kumihan.aozora.gr.jp/layout2.html

  # �P�s�����̎����� {{{
  def test_layout2_jsiage1
    # XXX �������̉��s�������ʒu�� Top �̒��H�O�H
    # See: http://kumihan.aozora.gr.jp/layout2.html#jisage

    ts = Parser.parse <<EOT
Hello
�m���R�������n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # �����̂͂���
    ts = Parser.parse <<EOT
�m���R�������n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Top.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # ���y�[�W�̌�
    ts = Parser.parse <<EOT
�m�����Łn
�m���R�������n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::PageBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # �������̏ꍇ�A�^�O�̑O�ɂ͕����͂��Ȃ��͂�
    assert_raises(Error::UnexpectedWord) do
      ts = Parser.parse <<EOT
Hello
����܁m���R�������n����������
World
EOT
    end
  end # }}}

  # �P�s�����̎����� - �� {{{
  def test_layout2_jsiage1__old
    ts = Parser.parse <<EOT
Hello
�m���V����R�������n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # �u���b�N�ł̎����� {{{
  def test_layout2_jsiage_multi
    ts = Parser.parse <<EOT
Hello
�m����������R�������n
�˂�
�Ȃ�
�m�������Ŏ������I���n
World
EOT
    expected =
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
    assert_equal expected, ts
  end # }}}

  # �u���b�N�ł̎����� - �s���H {{{
  def test_layout2_jsiage_multi__invalid
    # ref: �R�̌��p / ���O�����Y / 45642_txt_28273/usono_koyo.txt

    ts = Parser.parse <<EOT
Hello
�m����������W�������A�R�O���l�߁n
����������������������������������������������������������������������������������������������������
�m�������Ŏ������I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('����������������������������������������������������������������������������������������������������'),
              Tree::LineBreak.new,
            ],
            8,
            30
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # �܂�Ԃ��t��
    ts = Parser.parse <<EOT
Hello
�m����������U�������A�܂�Ԃ��ĂV�������A�Q�P���l�߁n
����������������������������������������
�m�������Ŏ������I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('����������������������������������������'),
              Tree::LineBreak.new,
            ],
            6,
            7,
            21
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # �܂�Ԃ��t��
    ts = Parser.parse <<EOT
Hello
�m����������T�������A�Q�X���l�߁A�y�[�W�̍��E�����Ɂn
����������������������������������������
�m�������Ŏ������I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::HorizontalCenter.new(
            [
              Tree::Top.new(
                [
                  Tree::Text.new('����������������������������������������'),
                  Tree::LineBreak.new,
                ],
                5,
                29
              ),
            ]
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # ���ʂ̕��G�Ȏ����� {{{
  def test_layout2_jsiage_cocomplex
    ts = Parser.parse <<EOT
Hello
�m����������P�������A�܂�Ԃ��ĂR�������n
�˂�
�Ȃ�
�m�������Ŏ������I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('�˂�'),
              Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'),
              Tree::LineBreak.new
            ],
            1,
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    ts = Parser.parse <<EOT
Hello
�m������������s�V�t���A�܂�Ԃ��ĂQ�������n
��A�˂��̂��킢���Ő��E�𐪕����A�n�����L���炯�ɂȂ�
��A�n������������
�m�������Ŏ������I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('��A�˂��̂��킢���Ő��E�𐪕����A�n�����L���炯�ɂȂ�'),
              Tree::LineBreak.new,
              Tree::Text.new('��A�n������������'),
              Tree::LineBreak.new
            ],
            nil,
            2
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # ���ʂ̕��G�Ȏ����� - �s�� {{{
  def test_layout2_jsiage_cocomplex__invalid
    ts = Parser.parse <<EOT
Hello
�m������������s�Q�������A�܂�Ԃ��ĂW�������n
�˂�
�Ȃ�
�m�������Ŏ������I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('�˂�'),
              Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'),
              Tree::LineBreak.new
            ],
            2,
            8
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # �n�t�� {{{
  def test_layout2_jistuki1
    ts = Parser.parse <<EOT
Hello
�m���n�t���n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            nil
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # ���y�[�W�̌�
    ts = Parser.parse <<EOT
�m�����Łn
�m���n�t���n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::PageBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            nil
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # �u���b�N�ł̒n�t�� # {{{
  def test_layout2_jistuki_multi
    ts = Parser.parse <<EOT
Hello
�m����������n�t���n
�˂�
�Ȃ�
�m�������Œn�t���I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('�˂�'),
              Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'),
              Tree::LineBreak.new
            ],
            nil
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # �n�� {{{
  def test_layout2_jiyose1
    ts = Parser.parse <<EOT
Hello
�m���n����P2���グ�n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            12
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # �������ƈႢ�A�O�ɕ����������Ă������񂾂�
    ts = Parser.parse <<EOT
�Ђ���ق��I�m���n����R���グ�n����������
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('�Ђ���ق��I'),
          Tree::Bottom.new(
            [
              Tree::Text.new('����������'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # �u���b�N�ł̒n�� {{{
  def test_layout2_jiyose_multi
    ts = Parser.parse <<EOT
Hello
�m����������n����Q���グ�n
�˂�
�Ȃ�
�m�������Ŏ��グ�I���n
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('�˂�'),
              Tree::LineBreak.new,
              Tree::Text.new('�Ȃ�'),
              Tree::LineBreak.new
            ],
            2
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # }}}

  # �y�[�W�̍��E�����ɑg��ł��鏈�� {{{

  # ���E���� {{{
  def test_horizontal_center
    ts = Parser.parse <<-EOT
�m���y�[�W�̍��E�����n
�˂��˂��ځ[��
�m�����y�[�W�n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::HorizontalCenter.new(
            [
                Tree::Text.new('�˂��˂��ځ[��'),
                Tree::LineBreak.new
            ]
          ),
          Tree::PageBreak.new
        ]
      );

    assert_equal expected, ts

    ts = Parser.parse <<-EOT
�m���y�[�W�̍��E�����n
�˂��˂��ځ[��
�m�������n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::HorizontalCenter.new(
            [
              Tree::Text.new('�˂��˂��ځ[��'),
              Tree::LineBreak.new
            ]
          ),
          Tree::SheetBreak.new
        ]
      );

    assert_equal expected, ts
  end # }}}

  # �������t�����E���� - �s�� {{{
  def test_top_with_horizontal_center__invalid
    # XXX ���֐��̂��߂ɁA���E�����̒��Ɏ�����������

    ts = Parser.parse <<-EOT
�m����������R�������A���E�����n
�˂��˂��ځ[��
�m�������Ŏ������I���n
�m�����y�[�W�n
EOT
    expected =
      Tree::Document.new(
        [
          Tree::HorizontalCenter.new(
            [
              Tree::Top.new(
                [
                  Tree::Text.new('�˂��˂��ځ[��'),
                  Tree::LineBreak.new
                ],
                3
              )
            ]
          ),
          Tree::PageBreak.new
        ]
      );

    assert_equal expected, ts
  end # }}}

  # }}}

  # ���o�� {{{

  # �ʏ�̌��o�� {{{
  def test_heading_normal
    ts = Parser.parse("meow\n�F���L�m���u�F���L�v�͒����o���n\nmeow")

    assert_equal 5, ts.size
    assert_equal Tree::Text.new('meow'),                                ts[0]
    assert_equal Tree::LineBreak.new,                                   ts[1]
    assert_equal Tree::Heading.new([Tree::Text.new('�F���L')], '��'),   ts[2]
    assert_equal Tree::LineBreak.new,                                   ts[3]
    assert_equal Tree::Text.new('meow'),                                ts[4]

    # FIXME
    #�m���匩�o���n���������������������m���匩�o���I���n
    #�m����������匩�o���n
    # ��������������������
    # ��������������������
    # �m�������ő匩�o���I���n
  end # }}}

  # ���s���o�� FIXME {{{
  def test_heading_on_same_line
    # ���o���̌�ɁA���s�����Œʏ�̕�������
    # �����������m���u�����������v�͓��s�����o���n�~�~�~�~�~�~�~
  end # }}}

  # �����o�� FIXME {{{
  def test_heading_window
    ts = Parser.parse('HOGE�����������m���u�����������v�͑������o���nFUGA')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HOGE'),
          Tree::WindowHeading.new(
            [
              Tree::Text.new('����������')
            ],
            '��'
          ),
          Tree::Text.new('FUGA'),
        ]
      )
    assert_equal expected, ts

    # ���r�����������p�^�[��
    ts = Parser.parse('HEAD�b�����s�܂�܂�t�m���u�����v�͑������o���nTAIL')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HEAD'),
          Tree::WindowHeading.new(
            [
              Tree::Ruby.new([Tree::Text.new('����')], '�܂�܂�')
            ],
            '��'
          ),
          Tree::Text.new('TAIL')
        ]
      )
    assert_equal expected, ts

    # ���r�����[�ɍ��������p�^�[��
    ts = Parser.parse('HEAD���b�����s�܂�܂�t�m���u�������v�͑������o���nTAIL')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HEAD'),
          Tree::WindowHeading.new(
            [
              Tree::Text.new('��'),
              Tree::Ruby.new([Tree::Text.new('����')], '�܂�܂�')
            ],
            '��'
          ),
          Tree::Text.new('TAIL')
        ]
      )
    assert_equal expected, ts

    # ���r�����������p�^�[��
    # + �����o���̃��r�́A�O���Q�ƌ^�̌��o�����L�ɂ͊܂߂Ȃ��ŁA�f�̃e�L�X�g�Ƃ���
    ts = Parser.parse('HEAD�ۊہs�܂�܂�t�m���u�ۊہv�͑������o���nTAIL')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HEAD'),
          Tree::WindowHeading.new(
            [
              Tree::Ruby.new([Tree::Text.new('�ۊ�')], '�܂�܂�')
            ],
            '��'
          ),
          Tree::Text.new('TAIL')
        ]
      )
    assert_equal expected, ts
  end # }}}

  # }}}

  # �O�� {{{

  # ��P��Q�����ɂȂ����� {{{
  def test_gaiji_jis
    ts = Parser.parse('�p�Ƃ����p��~�����m���u�M�{�d�v�A��4����2-12-11�n������')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('�p�Ƃ����p��~��'),
          Tree::JIS.new([Tree::Text.new('��')], '�u�M�{�d�v�A��4����2-12-11'),
          Tree::Text.new('������')
        ]
      )
    assert_equal expected, ts
  end # }}}

  # ����ȉ�����L���Ȃ� FIXME {{{
  def test_gaiji_kigou
    # ���m����̎��_�A1-2-22�n
    # ���m���t�@�C�i���V�O�}�A1-6-57�n
  end # }}}

  # �A�N�Z���g�����t���̃��e���E�A���t�@�x�b�g FIXME {{{
  def test_gaiji_accent
  end # }}}

  # Unicode �̊O�� - �s�� {{{
  def test_gaiji_unicode__invalid
    ts = Parser.parse('�ؖȂ̏㒅�Ɓb���m���u������ւ�{�Ɂv�Aunicode8932�n�q�s�N�[�V�t���͂�����')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('�ؖȂ̏㒅��'),
          Tree::Unicode.new([Tree::Text.new('��')], '�u������ւ�{�Ɂv�Aunicode8932'),
          Tree::Ruby.new([Tree::Text.new('�q')], '�N�[�V'),
          Tree::Text.new('���͂�����')
        ]
      )
    assert_equal expected, ts
  end

  # }}}

  # }}}

  # �P�_ {{{
  # http://kumihan.aozora.gr.jp/kunten.html

  # �Ԃ�_ FIXME {{{
  def test_kunten_kaeri_ten
  end # }}}

  # �P�_���艼�� FIXME {{{
  def test_kunten_okuri_gana
  end # }}}

  # �Ԃ�_�ƌP�_���艼���̍��� FIXME {{{
  def test_kunten_kaeri_ten_and_okuri_gana
  end # }}}

  # }}}

  # ���� {{{
  # http://kumihan.aozora.gr.jp/emphasis.html

  # �T�_ {{{
  def test_kyouchou_bouten
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

    # �ꕶ������Ă���
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

    # �e��T�_ FIXME
    #
    # �Ӂm���u�Ӂv�ɖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�ɔ��S�}�T�_�n�󕶌�
    # �Ӂm���u�Ӂv�ɊۖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�ɔ��ۖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�ɍ��O�p�T�_�n�󕶌�
    # �Ӂm���u�Ӂv�ɔ��O�p�T�_�n�󕶌�
    # �Ӂm���u�Ӂv�ɓ�d�ۖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�Ɏւ̖ږT�_�n�󕶌�

    # �͈͖T�_ FIXME
    # �m���T�_�n�󕶌ɂœǏ����悤�m���T�_�I���n
    # �m�����S�}�T�_�n�󕶌ɂœǏ����悤�m�����S�}�T�_�I���n�B
    # �m���ۖT�_�n�󕶌ɂœǏ����悤�m���ۖT�_�I���n�B
    # �m�����ۖT�_�n�󕶌ɂœǏ����悤�m�����ۖT�_�I���n�B
    # �m�����O�p�T�_�n�󕶌ɂœǏ����悤�m�����O�p�T�_�I���n�B
    # �m�����O�p�T�_�n�󕶌ɂœǏ����悤�m�����O�p�T�_�I���n�B
    # �m����d�ۖT�_�n�󕶌ɂœǏ����悤�m����d�ۖT�_�I���n�B
    # �m���ւ̖ږT�_�n�󕶌ɂœǏ����悤�m���ւ̖ږT�_�I���n�B

    # ���ɖT�_ FIXME
    # �Ӂm���u�Ӂv�̍��ɖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɔ��S�}�T�_�n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɊۖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɔ��ۖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɍ��O�p�T�_�n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɔ��O�p�T�_�n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɓ�d�ۖT�_�n�󕶌�
    # �Ӂm���u�Ӂv�̍��Ɏւ̖ږT�_�n�󕶌�

    # ���ɔ͈͖T�_ FIXME
    # �m�����ɖT�_�n�󕶌ɂœǏ����悤�m�����ɖT�_�I���n�B�@���@���ȉ��́A�V�����L�@�ł��B
    # �m�����ɔ��S�}�T�_�n�󕶌ɂœǏ����悤�m�����ɔ��S�}�T�_�I���n�B
    # �m�����ɊۖT�_�n�󕶌ɂœǏ����悤�m�����ɊۖT�_�I���n�B
    # �m�����ɔ��ۖT�_�n�󕶌ɂœǏ����悤�m�����ɔ��ۖT�_�I���n�B
    # �m�����ɍ��O�p�T�_�n�󕶌ɂœǏ����悤�m�����ɍ��O�p�T�_�I���n�B
    # �m�����ɔ��O�p�T�_�n�󕶌ɂœǏ����悤�m�����ɔ��O�p�T�_�I���n�B
    # �m�����ɓ�d�ۖT�_�n�󕶌ɂœǏ����悤�m�����ɓ�d�ۖT�_�I���n�B
    # �m�����Ɏւ̖ږT�_�n�󕶌ɂœǏ����悤�m�����Ɏւ̖ږT�_�I���n�B
  end # }}}

  # �T�� {{{
  def test_kyouchou_bousen
    # �T��
    ts = Parser.parse("�����̂Ƃ���͂˂����m���u�˂��v�͖T���n�Ȃ߂���")
    assert_equal Tree::Line.new([Tree::Text.new('�˂�')]),   ts[1]

    # �e��T�� FIXME
    # �Ӂm���u�Ӂv�ɖT���n�󕶌�
    # �Ӂm���u�Ӂv�ɓ�d�T���n�󕶌�
    # �Ӂm���u�Ӂv�ɍ����n�󕶌�
    # �Ӂm���u�Ӂv�ɔj���n�󕶌�
    # �Ӂm���u�Ӂv�ɔg���n�󕶌�

    # �m���T���n�󕶌ɂœǏ����悤�m���T���I���n�B�@���@���ȉ��́A�V�����L�@�ł��B
    # �m����d�T���n�󕶌ɂœǏ����悤�m����d�T���I���n�B
    # �m�������n�󕶌ɂœǏ����悤�m�������I���n�B
    # �m���j���n�󕶌ɂœǏ����悤�m���j���I���n�B
    # �m���g���n�󕶌ɂœǏ����悤�m���g���I���n�B
    #
    # �Ӂm���u�Ӂv�̍��ɖT���n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɓ�d�T���n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɍ����n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɔj���n�󕶌�
    # �Ӂm���u�Ӂv�̍��ɔg���n�󕶌�
    #
    # �m�����ɖT���n�󕶌ɂœǏ����悤�m�����ɖT���I���n�B�@���@���ȉ��́A�V�����L�@�ł��B
    # �m�����ɓ�d�T���n�󕶌ɂœǏ����悤�m�����ɓ�d�T���I���n�B
    # �m�����ɍ����n�󕶌ɂœǏ����悤�m�����ɍ����I���n�B
    # �m�����ɔj���n�󕶌ɂœǏ����悤�m�����ɔj���I���n�B
    # �m�����ɔg���n�󕶌ɂœǏ����悤�m�����ɔg���I���n�B
  end # }}}

  # �T�� - �s���H {{{
  def test_kyouchou_bousen__invalid
    return # FIXME
    ts = Parser.parse('���̔������L�s�˂��t�m���u�L�s�˂��t�v�ɖT���n�͂Ȃ񂾂낤�B')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('���̔�����'),
          Tree::Line.new(
            [
              Tree::Ruby.new([Tree::Text.new('�L')], '�˂�')
            ]
          ),
          Tree::Text.new('�͂Ȃ񂾂낤�B'),
        ]
      )
    assert_equal expected, ts
  end # }}}

  # ����(�S�V�b�N) {{{
  def test_kyouchou_bold
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

    # �͈� FIXME
  end # }}}

  # �Α�(�C�^���b�N) FIXME {{{
  def test_kyouchou_italic
  end # }}}

  # }}}

  # �摜 {{{
  # http://kumihan.aozora.gr.jp/graphics.html

  # �W�� FIXME {{{
  def test_gazou
    # �m�����V��̐}�ifig42154_01.png�A��321�~�c123�j����n
    # �m���u��ꎵ���@�����S���d�m���������䗝���i���ʁv�̃L���v�V�����t���̐}�ifig4990_07.png�A��321�~�c123�j����n
    # �m�����V��̐}�ifig42154_01.png�j����n
  end # }}}

  # ��W�� {{{
  def test_gazou__invalid
    ts = Parser.parse <<-EOT
����������
<img src="img/00.jpg">
����������
EOT
    assert_equal Tree::Image.new('img/00.jpg'),   ts[2]
  end # }}}

  # }}}

  # ���̑� {{{
  # http://kumihan.aozora.gr.jp/etc.html

  # �����Ɓu�}�}�v FIXME {{{
  def test_misc_fix
  end # }}}

  # ���r�ƃ��r�̂悤�ɕt������ {{{
  def test_misc_ruby
    # �P���ȗ�
    ts = Lexer.lex("�L�s�˂��t")
    assert_equal 2, ts.size
    assert_instance_of Token::Kanji,              ts[0]
    assert_equal       '�L',                      ts[0].text
    assert_instance_of Token::Ruby,               ts[1]
    assert_equal       '�˂�',                    ts[1].ruby

    # ���͂̒�
    ts = Parser.parse <<EOT
Hello
��y�͔L�s�˂��t�ł��邺��B
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('��y��'),
          Tree::Ruby.new([Tree::Text.new('�L')], '�˂�'),
          Tree::Text.new('�ł��邺��B'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # �c���ŋ�؂�ꂽ����
    ts = Parser.parse <<EOT
Hello
��y�́b�����킢�������́s�˂��t�ł��邺��B
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('��y��'),
          Tree::Ruby.new([Tree::Text.new('�����킢��������')], '�˂�'),
          Tree::Text.new('�ł��邺��B'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # ���L�ɂ������ă��r���ӂ��Ă������
    ts = Parser.parse('�V�q�����m���u�Ăւ�{�N�v�A��4����2-12-93�n�s�ˁt�����񂾂�')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('�V�q��'),
          Tree::Ruby.new(
            [Tree::JIS.new([Tree::Text.new('��')], '�Ăւ�{�N�v�A��4����2-12-93')],
            '��'
          ),
          Tree::Text.new('�����񂾂�')
        ]
      )
    assert_equal expected, ts

    # ���ɂ� FIXME
    # �󕶌Ɂm���u�󕶌Ɂv�̍��Ɂu��������Ԃ񂱁v�̃��r�n
  end # }}}

  # �c�g�ݒ��ŉ��ɕ��񂾕��� {{{
  def test_misc_yoko
    ts = Parser.parse("�����̂Ƃ���͂˂����m���u�˂��v�͏c�����n�Ȃ߂���")
    assert_equal Tree::Yoko.new([Tree::Text.new('�˂�')]),   ts[1]

    # �͈� FIXME
    #�m���c�����n�i���m�����[�}����1�A1-13-21�n�j�m���c�����I���n
  end # }}}

  # ���蒍 FIXME {{{
  def test_misc_warichu
  end # }}}

  # �s�E�������A�s�������������i�c�g�݁j FIXME {{{
  def test_misc_kogaki_tate
  end # }}}

  # ��t���������A���t���������i���g�݁j FIXME {{{
  def test_misc_kogaki_yoko
  end # }}}

  # �r�͂� FIXME {{{
  def test_misc_border_line
  end # }}}

  # ���g�݂̒�{ FIXME {{{
  def test_misc_yokogumi_book
  end # }}}

  # �c�g�ݖ{�����̉��g�� FIXME {{{
  def test_misc_yokogumi
  end # }}}

  # �����T�C�Y FIXME {{{
  def test_misc_char_size
  end # }}}

  # }}}

  # ���L�̏d�� FIXME {{{
  # }}}

  # �󕶌ɂ��z�������p�i�ԊO�j# {{{
  #   �{���I���
  #   �󕶌Ƀt�@�C���Ŏg���Ȃ�����
  #     ���r�L���ȂǁA���ʂȖ�����^����ꂽ����
  #     �O�����L�`���ɂ���֕\��
  # }}}

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
