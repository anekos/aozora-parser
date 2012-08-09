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
    t = Token::Annotation.new('猫なめ')

    assert_equal '猫なめ',  t.whole
    assert_equal nil,       t.target
    assert_equal nil,       t.spec
  end # }}}

  def test__with_target # {{{
    t = Token::Annotation.new('「猫」は太字')

    assert_equal '「猫」は太字',  t.whole
    assert_equal '猫',            t.target
    assert_equal '太字',          t.spec
  end # }}}

  def test__with_target_invalid # {{{
    t = Token::Annotation.new('も「猫」は太字')

    assert_equal 'も「猫」は太字',  t.whole
    assert_equal nil,               t.target
    assert_equal nil,               t.spec
  end # }}}
end # }}}

class TestLexer < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_line_break # {{{
    ts = Lexer.lex("いちぎょうめ\nにぎょうめ")

    assert_equal 3, ts.size
    assert_instance_of Token::Hiragana,   ts[0]
    assert_equal       'いちぎょうめ',    ts[0].text
    assert_instance_of Token::LineBreak,  ts[1]
    assert_instance_of Token::Hiragana,   ts[2]
    assert_equal       'にぎょうめ',      ts[2].text
  end # }}}

  def test_text # {{{
    ts = Lexer.lex("ねこはかわいい")

    assert 1, ts.size
    assert_instance_of Token::Hiragana,   ts[0]
    assert_equal       'ねこはかわいい',  ts[0].text
  end # }}}

  def test_char_type # {{{
    ts = Lexer.lex("私はネコを舐める")

    assert_equal 6, ts.size
    assert_instance_of Token::Kanji,       ts[0] # 私
    assert_instance_of Token::Hiragana,    ts[1] # は
    assert_instance_of Token::Katakana,    ts[2] # ネコ
    assert_instance_of Token::Hiragana,    ts[3] # を
    assert_instance_of Token::Kanji,       ts[4] # 舐
    assert_instance_of Token::Hiragana,    ts[5] # める
  end # }}}

  def test_marks # {{{
    ts = Lexer.lex("foo｜※bar")

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
今日のところはねこ［＃「ねこ」に傍点］をなめたい
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
【テキスト中に現れる記号について】

《》：ルビ
（例）沽券《こけん》

［＃］：入力者注　主に外字の説明や、傍点の位置の指定
　　　（数字は、JIS X 0213の面区点番号、または底本のページと行数）
（例）2［＃「2」はローマ数字、1-13-22］
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
ひっ［＃「ひっ」に傍点］外して［＃「ひっ［＃「ひっ」に傍点］外して」は底本では「ひっ外［＃「っ外」に傍点］して」］右へ
EOT
    expected =
      [
        Token::Hiragana.new('ひっ'),
        Token::Annotation.new('「ひっ」に傍点'),
        Token::Kanji.new('外'),
        Token::Hiragana.new('して'),
        Token::Annotation.new('「ひっ［＃「ひっ」に傍点］外して」は底本では「ひっ外［＃「っ外」に傍点］して」'),
        Token::Kanji.new('右'),
        Token::Hiragana.new('へ'),
        Token::LineBreak.new
      ]
    assert_equal expected, ts
  end # }}}

  def test_ignore_bottom_info # {{{
    ts = Parser.parse <<-EOT
ほんぶん1
ほんぶん2
ほんぶん3
底本：「現代日本思想大系　14　芸術の思想」筑摩書房
　　　1964（昭和39）年8月15日発行
入力：土屋隆
校正：染川隆俊
2008年1月25日作成
青空文庫作成ファイル：
このファイルは、インターネットの図書館、青空文庫（http://www.aozora.gr.jp/）で作られました。入力、校正、制作にあたったのは、ボランティアの皆さんです。
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('ほんぶん1'),
          Tree::LineBreak.new,
          Tree::Text.new('ほんぶん2'),
          Tree::LineBreak.new,
          Tree::Text.new('ほんぶん3'),
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
    assert_block { Tree::Text.new('ほげ') == Tree::Text.new('ほげ') }
    assert_block { not Tree::Text.new('ほげ') == Tree::Text.new('もげ') }
    assert_block { not Tree::Text.new('ほげ') == Tree::Ruby.new([Tree::Text.new('ほげ')]) }
    assert_block { Tree::Text.new('ほげ').text == Tree::Ruby.new([Tree::Text.new('ほげ')]).text }

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
    # 分割されたものは、元のコンテナに入っている

    l, r =
      Tree::Block.new([
        Tree::Ruby.new([Tree::Text.new('〇一')]),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(3)
    assert_equal Tree::Block.new([Tree::Ruby.new([Tree::Text.new('〇一')]), Tree::Text.new('二')]), l
    assert_equal Tree::Block.new([Tree::Text.new('三四五六七八九')]),                               r

    l, r =
      Tree::Block.new([
        Tree::Bold.new([Tree::Text.new('〇一')]),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(3)

    assert_equal Tree::Block.new([
                  Tree::Bold.new([Tree::Text.new('〇一')]),
                  Tree::Text.new('二')
                 ]),  l
    assert_equal Tree::Block.new([Tree::Text.new('三四五六七八九')]), r

    l, r =
      Tree::Block.new([
        Tree::Bold.new([Tree::Text.new('〇一')]),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(2)
    assert_equal Tree::Block.new([
                  Tree::Bold.new([Tree::Text.new('〇一')]),
                 ]),  l
    assert_equal Tree::Block.new([Tree::Text.new('二三四五六七八九')]), r
  end # }}}

  def test_split__simple # {{{
    # 分割されたものは、元のコンテナに入っている

    l, r =
      Tree::Block.new([
        Tree::Text.new('〇一'),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(3)

    assert_equal Tree::Block.new([Tree::Text.new('〇一二')]),            l
    assert_equal Tree::Block.new([Tree::Text.new('三四五六七八九')]),    r

    l, r =
      Tree::Bold.new([
        Tree::Text.new('〇一'),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(3)

    assert_equal Tree::Bold.new([Tree::Text.new('〇一二')]),            l
    assert_equal Tree::Bold.new([Tree::Text.new('三四五六七八九')]),    r
  end # }}}

  def test_split__empty # {{{
    # XXX 空になる場合は nil

    l, r =
      Tree::Block.new([
        Tree::Text.new('〇一'),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(0)

    assert_equal nil,                                                         l
    assert_equal Tree::Block.new([Tree::Text.new('〇一二三四五六七八九')]),   r


    l, r =
      Tree::Block.new([
        Tree::Text.new('〇一'),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(10)

    assert_equal Tree::Block.new([Tree::Text.new('〇一二三四五六七八九')]),   l
    assert_equal nil,                                                         r


    l, r =
      Tree::Block.new([
        Tree::Text.new('〇一'),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(11)

    assert_equal Tree::Block.new([Tree::Text.new('〇一二三四五六七八九')]),   l
    assert_equal nil,                                                         r


    l, r =
      Tree::Block.new([
        Tree::Text.new('〇一'),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split(9)

    assert_equal Tree::Block.new([Tree::Text.new('〇一二三四五六七八')]),    l
    assert_equal Tree::Block.new([Tree::Text.new('九')]),                    r
  end # }}}

  def test_split_by_text # {{{
    # XXX テキストが連続する場合は、連結する

    l, c, r =
      Tree::Block.new([
        Tree::Ruby.new([
          Tree::Text.new('〇一')
        ]),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split_by_text('三四五')
    assert_equal Tree::Block.new([Tree::Ruby.new([Tree::Text.new('〇一')]), Tree::Text.new('二')]),
                                                  l
    assert_equal Tree::Block.new([Tree::Text.new('三四五')]),        c
    assert_equal Tree::Block.new([Tree::Text.new('六七八九')]),      r


    l, c, r =
      Tree::Document.new([
        Tree::Text.new('HEAD'),
        Tree::Ruby.new([Tree::Text.new('二三四')], 'ルビ'),
        Tree::Text.new('TAIL'),
      ]).split_by_text('二三四')
    assert_equal Tree::Document.new([Tree::Text.new('HEAD')]), l


    # ルビ(ブロック)を分割することはできない
    ruby = Tree::Ruby.new([Tree::Text.new('foobarbaz')], 'メタ構文変数')
    assert_raises(Error::SplitBlockByForwardRef) do
      ruby.split_by_text('bar')
    end
  end # }}}

  def test_split_by_text__simple # {{{
    l, c, r =
      Tree::Block.new([
        Tree::Text.new('〇一'),
        Tree::Text.new('二三四'),
        Tree::Text.new('五六七八九'),
      ]).split_by_text('二三四')

    assert_equal Tree::Block.new([Tree::Text.new('〇一')]),        l
    assert_equal Tree::Block.new([Tree::Text.new('二三四')]),      c
    assert_equal Tree::Block.new([Tree::Text.new('五六七八九')]),  r
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
    t = Tree::Text.new('ねこりんちょ')

    assert_equal 'ねこりんちょ',    t.text
  end # }}}

  def test_split # {{{
    l, r = Tree::Text.new('〇一二三四五六七八九').split(4)
    assert_equal Tree::Text.new('〇一二三'),      l
    assert_equal Tree::Text.new('四五六七八九'),  r

    l, r = Tree::Text.new('〇一二三四五六七八九').split(10)
    assert_equal Tree::Text.new('〇一二三四五六七八九'),    l
    assert_equal nil,                                       r

    l, r = Tree::Text.new('〇一二三四五六七八九').split(1)
    assert_equal Tree::Text.new('〇'),                    l
    assert_equal Tree::Text.new('一二三四五六七八九'),    r

    l, r = Tree::Text.new('〇一二三四五六七八九').split(0)
    assert_equal nil,                                       l
    assert_equal Tree::Text.new('〇一二三四五六七八九'),    r
  end # }}}

  def test_split_by_text # {{{
    # XXX 文字列の長さが零になる場合は、nil を返し省略する

    # 真ん中
    l, c, r = Tree::Text.new('〇一二三四五六七八九').split_by_text('三四五')

    assert_equal Tree::Text.new('〇一二'),    l
    assert_equal Tree::Text.new('三四五'),    c
    assert_equal Tree::Text.new('六七八九'),  r

    # 左寄り
    l, c, r = Tree::Text.new('〇一二三四五六七八九').split_by_text('〇一二')

    assert_equal nil,                               l
    assert_equal Tree::Text.new('〇一二'),          c
    assert_equal Tree::Text.new('三四五六七八九'),  r

    # 右寄り
    l, c, r = Tree::Text.new('〇一二三四五六七八九').split_by_text('七八九')

    assert_equal Tree::Text.new('〇一二三四五六'),  l
    assert_equal Tree::Text.new('七八九'),          c
    assert_equal nil,                               r
  end # }}}
end # }}}

class TestTreeRuby < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_text # {{{
    t =
      Tree::Ruby.new([
        Tree::Text.new('〇一二'),
        Tree::Text.new('三四五六七八九')
      ])

    assert_equal '〇一二三四五六七八九',    t.text
  end # }}}
end # }}}

class TestTreeJIS < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_new # {{{
    t = Tree::JIS.new([Tree::Text.new('foo')], '「廴＋囘」、第4水準2-12-11')
    assert_equal [2, 12, 11],     t.char.code
    assert_equal 4,               t.char.level
    assert_equal ['廴', '囘'],    t.char.parts

    t = Tree::JIS.new([Tree::Text.new('foo')], '「廴＋囘」、第四水準2-12-11')
    assert_equal 4,               t.char.level

    t = Tree::JIS.new([Tree::Text.new('foo')], '「廴＋囘」、第４水準2-12-11')
    assert_equal 4,               t.char.level
  end # }}}
end # }}}

class TestTreeUnicode < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_new # {{{
    t = Tree::Unicode.new([Tree::Text.new('※')], '「ころもへん＋庫」、unicode8932')
    assert_equal [Tree::Text.new('※')],  t.items
    assert_equal 0x8932,                  t.char.code
    assert_equal ['ころもへん', '庫'],    t.char.parts
  end # }}}
end # }}}

class TestTreeChar < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_jis # {{{
    c = Char::JIS.parse('「廴＋囘」、第4水準2-12-11')
    assert_equal 4,             c.level
    assert_equal [2, 12, 11],   c.code
    assert_equal ['廴', '囘'],  c.parts

    c = Char::JIS.parse('「ねこみみ＋囘」、第4水準2-12-11')
    assert_equal 4,                   c.level
    assert_equal [2, 12, 11],         c.code
    assert_equal ['ねこみみ', '囘'],  c.parts

    assert_raises(Error::Format) { Char::JIS.parse('「廴＋囘」、第4水準2+12+11') }
  end # }}}

  def test_unicode # {{{
    c = Char::Unicode.parse('「ころもへん＋庫」、unicode8932')
    assert_equal 0x8932,                c.code
    assert_equal ['ころもへん', '庫'],  c.parts

    assert_raises(Error::Format) { p Char::Unicode.parse('「ころもへん＋庫」、unicode89x2').code }
  end # }}}
end # }}}

class TestParser < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  def test_simple_text # {{{
    ts = Parser.parse('ねこを舐めたい')

    assert_equal 1, ts.size
    assert_instance_of Tree::Text, ts[0]
  end # }}}

  def test_three_lines # {{{
    ts = Parser.parse <<EOT
ネコ舐め
あabcい
みげ
EOT

    assert_equal 6, ts.size
    assert_instance_of Tree::Text,      ts[0]
    assert_equal       'ネコ舐め',      ts[0].text
    assert_instance_of Tree::LineBreak, ts[1]
    assert_instance_of Tree::Text,      ts[2]
    assert_equal       'あabcい',       ts[2].text
    assert_instance_of Tree::LineBreak, ts[3]
    assert_instance_of Tree::Text,      ts[4]
    assert_equal       'みげ',          ts[4].text
    assert_instance_of Tree::LineBreak, ts[5]
  end # }}}

  def test_target_annotation # {{{
    ts = Parser.parse("今日のところはねこを［＃「ねこ」に傍点］なめたい")

    assert_equal 3, ts.size
    assert_instance_of Tree::Text,              ts[0]
    assert_instance_of Tree::Text,              ts[2]
    assert_equal       'をなめたい',            ts[2].text

    inner = [Tree::Text.new('ねこ')]

    assert_equal Tree::Dots.new(inner),   ts[1]

    ts = Parser.parse("今日のところはねこを［＃「ねこ」は縦中横］なめたい")
    assert_equal Tree::Yoko.new(inner),   ts[1]

    ts = Parser.parse("今日のところはねこを［＃「ねこ」は太字］なめたい")
    assert_equal Tree::Bold.new(inner),   ts[1]

    ts = Parser.parse("今日のところはねこを［＃「ねこ」は傍線］なめたい")
    assert_equal Tree::Line.new(inner),   ts[1]
  end # }}}

  def test_unkown # {{{
    ts = Parser.parse <<EOT
Hello
［＃うちゅうだ！それはうちゅうだ！］
World
EOT

    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Unknown.new(Token::Annotation.new('うちゅうだ！それはうちゅうだ！')),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts


    ts = Parser.parse <<EOT
Hello
ねこ［＃「ねこ」はうちゅうさ］
World
EOT

    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('ねこ'),
          Tree::Unknown.new(Token::Annotation.new('「ねこ」はうちゅうさ')),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  def test_rice_mark # {{{
    # XXX ※は特に何もなければ、そのまま出力する

    ts = Parser.parse <<EOT
Hello
私は※が大好きです。
World
EOT

    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('私は※が大好きです。'),
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
私は｜※※※※［＃ねこ］が大好きです。
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('私は'),
          Tree::Note.new([Tree::Text.new('※※※※')], 'ねこ'),
          Tree::Text.new('が大好きです。'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    ts = Parser.parse <<EOT
Hello
私は｜※［＃ねこ］が大好きです。
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('私は'),
          Tree::Note.new([Tree::Text.new('※')], 'ねこ'),
          Tree::Text.new('が大好きです。'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    ts = Parser.parse <<EOT
Hello
私は※※※※［＃ねこ］が大好きです。
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('私は'),
          Tree::Note.new([Tree::Text.new('※※※※')], 'ねこ'),
          Tree::Text.new('が大好きです。'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    ts = Parser.parse <<EOT
Hello
私は※［＃ねこ］が大好きです。
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('私は'),
          Tree::Note.new([Tree::Text.new('※')], 'ねこ'),
          Tree::Text.new('が大好きです。'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  def test_block_annotation # {{{
    # XXX 改行をいれる位置にちゅうい
    # See: http://kumihan.aozora.gr.jp/layout2.html#jisage

    ts = Parser.parse <<EOT
Hello
［＃ここから３字下げ］
ねこ
なめ
［＃ここで字下げ終わり］
World
EOT

    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('ねこ'),
              Tree::LineBreak.new,
              Tree::Text.new('なめ'),
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
    # XXX 連続する場合は、途中の終了タグを省略できる
    # See: http://kumihan.aozora.gr.jp/layout2.html#jisage

    ts = Parser.parse <<EOT
［＃ここから２字下げ］
one
［＃ここから４字下げ］
two
three
［＃ここで字下げ終わり］
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
［＃ここから３字下げ］
ねこ
なめ
［＃ここで地付き終わり］
World
EOT
    end
  end # }}}

  def test_no_block_end # {{{
    # XXX デフォルトでは、エラーチェックしない
    ts = Parser.parse(<<EOT)
Hello
［＃ここから３字下げ］
ねこ
なめ
EOT

    assert_raises(Error::NoBlockEnd) do
      opt = ParserOption.new(:check_last_block_end => true)
      ts = Parser.parse(<<EOT, opt)
Hello
［＃ここから３字下げ］
ねこ
なめ
EOT
    end

    # 最後のブロックは閉じているのが、違う種類のブロックが続いているのでエラー
    assert_raises(Error::NoBlockEnd) do
      opt = ParserOption.new(:check_last_block_end => true)
      ts = Parser.parse(<<EOT, opt)
Hello
［＃ここから３字下げ］
ねこ
なめ
［＃ここから地付き］
［＃ここで地付き終わり］
EOT
    end

    # 同じ種類のブロックで連続しているのでエラーにならない
    ts = Parser.parse <<EOT
Hello
［＃ここから３字下げ］
ねこ
なめ
［＃ここから５字下げ］
りんちょ
［＃ここで字下げ終わり］
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'), Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('ねこ'), Tree::LineBreak.new,
              Tree::Text.new('なめ'), Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Top.new(
            [
              Tree::Text.new('りんちょ'), Tree::LineBreak.new,
            ],
            5
          ),
        ]
      )
    assert_equal expected, ts

    # 同じ種類のブロックで連続しているのでエラーにならない
    # 全く同じクラスではないが、サブクラス <-> スーパークラスの関係
    ts = Parser.parse <<EOT
Hello
［＃ここから改行天付き、折り返して１字下げ］
ねこ
なめ
［＃ここから５字下げ］
りんちょ
［＃ここで字下げ終わり］
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'), Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('ねこ'), Tree::LineBreak.new,
              Tree::Text.new('なめ'), Tree::LineBreak.new,
            ],
            nil,
            1
          ),
          Tree::Top.new(
            [
              Tree::Text.new('りんちょ'), Tree::LineBreak.new,
            ],
            5
          ),
        ]
      )
    assert_equal expected, ts

    begin
      ts = Parser.parse <<EOT
Hello
［＃ここから３字下げ］
なめ
［＃ここから地付き］
［＃ここで地付き終わり］
EOT
    rescue => e
      assert_instance_of Error::NoBlockEnd,   e
      assert_instance_of Tree::Top,           e.node
    end

    ts = Parser.parse <<EOT
Hello
［＃ここから３字下げ］
one
猫［＃「猫」は太字］
two
［＃ここで字下げ終わり］
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
              Tree::Bold.new([Tree::Text.new('猫')]),
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
    # TODO 正確でない場合がありそう

    ts = Parser.parse <<-EOT
あいうえお
かきくけこ
さしすせそ
EOT
    assert_equal 1, ts[0].token.line
    assert_equal 3, ts[5].token.line

    ts = Parser.parse <<-EOT
あいうえお
かきくけこ
［＃ここから３字下げ］
［＃ここで字下げ終わり］
EOT
    assert_equal        1,                      ts[0].token.line
    assert_equal        Tree::LineBreak.new,    ts[3]
    assert_instance_of  Tree::Top,              ts[4]
    assert_equal        3,                      ts[4].token.line

    ts = Parser.parse <<-EOT
ねこ［＃「ねこ」に傍点］
EOT
    assert_instance_of  Tree::Dots,   ts[0]
    assert_equal        1,            ts[0].token.line
  end # }}}

  def test_continued_top
    assert_not_raise do
      ts = Parser.parse <<EOT
［＃天から１７字下げ］八、執作……………8.〔kammaka_ri_ ca bhariya_ ca〕（〔karmaka_ri_ ca dhaja_hata〕［＃tは下ドット付き］）
［＃天から１７字下げ］九、擧旗婦…………9.〔dhaja-hrita_〕［＃rは下ドット付き］（〔dhvaja-hrita_〕［＃rは下ドット付き］）
［＃天から２６字下げ］10.〔muhuttika_〕（〔tamkhanika_〕［＃mは上ドット付き。nは下ドット付き］）（〔tatksanika_〕［＃sは下ドット付き］）
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

# 青空文庫注記仕様

class TestAozoraSpec < MiniTest::Unit::TestCase # {{{
  include AozoraParser

  # ページや段をあらためる処理 {{{
  # http://kumihan.aozora.gr.jp/layout1.html

  # 改丁 {{{
  def test_layout1_kaicho
    ts = Parser.parse(<<EOT)
［＃改丁］
EOT
    expected =
      Tree::Document.new(
        [
          Tree::SheetBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # 改ページ {{{
  def test_layout1_kaipage
    ts = Parser.parse(<<EOT)
［＃改ページ］
EOT
    expected =
      Tree::Document.new(
        [
          Tree::PageBreak.new
        ]
      )
    assert_equal expected, ts
  end # }}}

  # 改段 {{{
  def test_layout1_kaidan
    ts = Parser.parse(<<EOT)
［＃改段］
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

  # 字下げ {{{
  # http://kumihan.aozora.gr.jp/layout2.html

  # １行だけの字下げ {{{
  def test_layout2_jsiage1
    # XXX 字下げの改行をいれる位置は Top の中？外？
    # See: http://kumihan.aozora.gr.jp/layout2.html#jisage

    ts = Parser.parse <<EOT
Hello
［＃３字下げ］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('ここだけさ'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # 文書のはじめ
    ts = Parser.parse <<EOT
［＃３字下げ］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Top.new(
            [
              Tree::Text.new('ここだけさ'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # 改ページの後
    ts = Parser.parse <<EOT
［＃改頁］
［＃３字下げ］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::PageBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('ここだけさ'),
              Tree::LineBreak.new,
            ],
            3
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # 字下げの場合、タグの前には文字はこないはず
    assert_raises(Error::UnexpectedWord) do
      ts = Parser.parse <<EOT
Hello
じゃま［＃３字下げ］ここだけさ
World
EOT
    end
  end # }}}

  # １行だけの字下げ - 旧 {{{
  def test_layout2_jsiage1__old
    ts = Parser.parse <<EOT
Hello
［＃天から３字下げ］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('ここだけさ'),
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

  # ブロックでの字下げ {{{
  def test_layout2_jsiage_multi
    ts = Parser.parse <<EOT
Hello
［＃ここから３字下げ］
ねこ
なめ
［＃ここで字下げ終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('ねこ'),
              Tree::LineBreak.new,
              Tree::Text.new('なめ'),
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

  # ブロックでの字下げ - 不正？ {{{
  def test_layout2_jsiage_multi__invalid
    # ref: 嘘の効用 / 末弘厳太郎 / 45642_txt_28273/usono_koyo.txt

    ts = Parser.parse <<EOT
Hello
［＃ここから８字下げ、３０字詰め］
あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ
［＃ここで字下げ終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Top.new(
            [
              Tree::Text.new('あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ'),
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

    # 折り返し付き
    ts = Parser.parse <<EOT
Hello
［＃ここから６字下げ、折り返して７字下げ、２１字詰め］
あいうえおかきくけこあいうえおかきくけこ
［＃ここで字下げ終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('あいうえおかきくけこあいうえおかきくけこ'),
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

    # 折り返し付き
    ts = Parser.parse <<EOT
Hello
［＃ここから５字下げ、２９字詰め、ページの左右中央に］
あいうえおかきくけこあいうえおかきくけこ
［＃ここで字下げ終わり］
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
                  Tree::Text.new('あいうえおかきくけこあいうえおかきくけこ'),
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

  # 凹凸の複雑な字下げ {{{
  def test_layout2_jsiage_cocomplex
    ts = Parser.parse <<EOT
Hello
［＃ここから１字下げ、折り返して３字下げ］
ねこ
なめ
［＃ここで字下げ終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('ねこ'),
              Tree::LineBreak.new,
              Tree::Text.new('なめ'),
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
［＃ここから改行天付き、折り返して２字下げ］
一、ねこのかわいさで世界を征服し、地球が猫だらけになる
一、地球が爆発する
［＃ここで字下げ終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('一、ねこのかわいさで世界を征服し、地球が猫だらけになる'),
              Tree::LineBreak.new,
              Tree::Text.new('一、地球が爆発する'),
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

  # 凹凸の複雑な字下げ - 不正 {{{
  def test_layout2_jsiage_cocomplex__invalid
    ts = Parser.parse <<EOT
Hello
［＃ここから改行２字下げ、折り返して８字下げ］
ねこ
なめ
［＃ここで字下げ終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::TopWithTurn.new(
            [
              Tree::Text.new('ねこ'),
              Tree::LineBreak.new,
              Tree::Text.new('なめ'),
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

  # 地付き {{{
  def test_layout2_jistuki1
    ts = Parser.parse <<EOT
Hello
［＃地付き］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('ここだけさ'),
              Tree::LineBreak.new,
            ],
            nil
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # 改ページの後
    ts = Parser.parse <<EOT
［＃改頁］
［＃地付き］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::PageBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('ここだけさ'),
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

  # ブロックでの地付き # {{{
  def test_layout2_jistuki_multi
    ts = Parser.parse <<EOT
Hello
［＃ここから地付き］
ねこ
なめ
［＃ここで地付き終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('ねこ'),
              Tree::LineBreak.new,
              Tree::Text.new('なめ'),
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

  # 地寄せ {{{
  def test_layout2_jiyose1
    ts = Parser.parse <<EOT
Hello
［＃地から１2字上げ］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('ここだけさ'),
              Tree::LineBreak.new,
            ],
            12
          ),
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # 字下げと違い、前に文字があってもいいんだよ
    ts = Parser.parse <<EOT
ひゃっほう！［＃地から３字上げ］ここだけさ
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('ひゃっほう！'),
          Tree::Bottom.new(
            [
              Tree::Text.new('ここだけさ'),
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

  # ブロックでの地寄せ {{{
  def test_layout2_jiyose_multi
    ts = Parser.parse <<EOT
Hello
［＃ここから地から２字上げ］
ねこ
なめ
［＃ここで字上げ終わり］
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Bottom.new(
            [
              Tree::Text.new('ねこ'),
              Tree::LineBreak.new,
              Tree::Text.new('なめ'),
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

  # ページの左右中央に組んである処理 {{{

  # 左右中央 {{{
  def test_horizontal_center
    ts = Parser.parse <<-EOT
［＃ページの左右中央］
ねこねこぼーい
［＃改ページ］
EOT
    expected =
      Tree::Document.new(
        [
          Tree::HorizontalCenter.new(
            [
                Tree::Text.new('ねこねこぼーい'),
                Tree::LineBreak.new
            ]
          ),
          Tree::PageBreak.new
        ]
      );

    assert_equal expected, ts

    ts = Parser.parse <<-EOT
［＃ページの左右中央］
ねこねこぼーい
［＃改丁］
EOT
    expected =
      Tree::Document.new(
        [
          Tree::HorizontalCenter.new(
            [
              Tree::Text.new('ねこねこぼーい'),
              Tree::LineBreak.new
            ]
          ),
          Tree::SheetBreak.new
        ]
      );

    assert_equal expected, ts
  end # }}}

  # 字下げ付き左右中央 - 不正 {{{
  def test_top_with_horizontal_center__invalid
    # XXX 利便性のために、左右中央の中に字下げを入れる

    ts = Parser.parse <<-EOT
［＃ここから３字下げ、左右中央］
ねこねこぼーい
［＃ここで字下げ終わり］
［＃改ページ］
EOT
    expected =
      Tree::Document.new(
        [
          Tree::HorizontalCenter.new(
            [
              Tree::Top.new(
                [
                  Tree::Text.new('ねこねこぼーい'),
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

  # 見出し {{{

  # 通常の見出し {{{
  def test_heading_normal
    ts = Parser.parse("meow\n宇宙猫［＃「宇宙猫」は中見出し］\nmeow")

    assert_equal 5, ts.size
    assert_equal Tree::Text.new('meow'),                                ts[0]
    assert_equal Tree::LineBreak.new,                                   ts[1]
    assert_equal Tree::Heading.new([Tree::Text.new('宇宙猫')], '中'),   ts[2]
    assert_equal Tree::LineBreak.new,                                   ts[3]
    assert_equal Tree::Text.new('meow'),                                ts[4]

    # FIXME
    #［＃大見出し］○○○○○○○○○○［＃大見出し終わり］
    #［＃ここから大見出し］
    # ○○○○○○○○○○
    # ○○○○○○○○○○
    # ［＃ここで大見出し終わり］
  end # }}}

  # 同行見出し FIXME {{{
  def test_heading_on_same_line
    # 見出しの後に、改行無しで通常の文が続く
    # ○○○○○［＃「○○○○○」は同行中見出し］×××××××
  end # }}}

  # 窓見出し FIXME {{{
  def test_heading_window
    ts = Parser.parse('HOGE○○○○○［＃「○○○○○」は窓中見出し］FUGA')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HOGE'),
          Tree::WindowHeading.new(
            [
              Tree::Text.new('○○○○○')
            ],
            '中'
          ),
          Tree::Text.new('FUGA'),
        ]
      )
    assert_equal expected, ts

    # ルビが混ざったパターン
    ts = Parser.parse('HEAD｜○○《まるまる》［＃「○○」は窓中見出し］TAIL')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HEAD'),
          Tree::WindowHeading.new(
            [
              Tree::Ruby.new([Tree::Text.new('○○')], 'まるまる')
            ],
            '中'
          ),
          Tree::Text.new('TAIL')
        ]
      )
    assert_equal expected, ts

    # ルビが半端に混ざったパターン
    ts = Parser.parse('HEAD△｜○○《まるまる》［＃「△○○」は窓中見出し］TAIL')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HEAD'),
          Tree::WindowHeading.new(
            [
              Tree::Text.new('△'),
              Tree::Ruby.new([Tree::Text.new('○○')], 'まるまる')
            ],
            '中'
          ),
          Tree::Text.new('TAIL')
        ]
      )
    assert_equal expected, ts

    # ルビが混ざったパターン
    # + 窓見出しのルビは、前方参照型の見出し注記には含めないで、素のテキストとする
    ts = Parser.parse('HEAD丸丸《まるまる》［＃「丸丸」は窓中見出し］TAIL')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('HEAD'),
          Tree::WindowHeading.new(
            [
              Tree::Ruby.new([Tree::Text.new('丸丸')], 'まるまる')
            ],
            '中'
          ),
          Tree::Text.new('TAIL')
        ]
      )
    assert_equal expected, ts
  end # }}}

  # }}}

  # 外字 {{{

  # 第１第２水準にない漢字 {{{
  def test_gaiji_jis
    ts = Parser.parse('叢という叢を掻き※［＃「廴＋囘」、第4水準2-12-11］したり')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('叢という叢を掻き'),
          Tree::JIS.new([Tree::Text.new('※')], '「廴＋囘」、第4水準2-12-11'),
          Tree::Text.new('したり')
        ]
      )
    assert_equal expected, ts
  end # }}}

  # 特殊な仮名や記号など FIXME {{{
  def test_gaiji_kigou
    # ※［＃二の字点、1-2-22］
    # ※［＃ファイナルシグマ、1-6-57］
  end # }}}

  # アクセント符号付きのラテン・アルファベット FIXME {{{
  def test_gaiji_accent
  end # }}}

  # Unicode の外字 - 不正 {{{
  def test_gaiji_unicode__invalid
    ts = Parser.parse('木綿の上着と｜※［＃「ころもへん＋庫」、unicode8932］子《クーシ》をはいた女')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('木綿の上着と'),
          Tree::Unicode.new([Tree::Text.new('※')], '「ころもへん＋庫」、unicode8932'),
          Tree::Ruby.new([Tree::Text.new('子')], 'クーシ'),
          Tree::Text.new('をはいた女')
        ]
      )
    assert_equal expected, ts
  end

  # }}}

  # }}}

  # 訓点 {{{
  # http://kumihan.aozora.gr.jp/kunten.html

  # 返り点 FIXME {{{
  def test_kunten_kaeri_ten
  end # }}}

  # 訓点送り仮名 FIXME {{{
  def test_kunten_okuri_gana
  end # }}}

  # 返り点と訓点送り仮名の混在 FIXME {{{
  def test_kunten_kaeri_ten_and_okuri_gana
  end # }}}

  # }}}

  # 強調 {{{
  # http://kumihan.aozora.gr.jp/emphasis.html

  # 傍点 {{{
  def test_kyouchou_bouten
    ts = Parser.parse("今日のところはねこ［＃「ねこ」に傍点］をなめたい")

    assert_equal 3, ts.size
    assert_instance_of Tree::Text,              ts[0]
    assert_instance_of Tree::Dots,              ts[1]
    assert_instance_of Tree::Text,              ts[2]
    assert_equal       'をなめたい',            ts[2].text

    dots = ts[1]
    assert_equal 1, dots.size
    assert_instance_of Tree::Text,  dots[0]
    assert_equal       'ねこ',      dots.text
    assert_equal       'ねこ',      dots[0].text

    # 一文字離れている
    ts = Parser.parse("おはよう！\nなぜかねこを［＃「ねこ」に傍点］なめたいね")

    assert_equal 5, ts.size
    assert_equal Tree::Text.new('おはよう！'),              ts[0]
    assert_equal Tree::LineBreak.new,                       ts[1]
    assert_equal Tree::Text.new('なぜか'),                  ts[2]
    assert_equal Tree::Dots.new([Tree::Text.new('ねこ')]),  ts[3]
    assert_equal Tree::Text.new('をなめたいね'),            ts[4]

    dots = ts[3]
    assert_equal 1, dots.size
    assert_instance_of Tree::Text,  dots[0]
    assert_equal       'ねこ',      dots.text
    assert_equal       'ねこ',      dots[0].text

    # 各種傍点 FIXME
    #
    # 責［＃「責」に傍点］空文庫
    # 責［＃「責」に白ゴマ傍点］空文庫
    # 責［＃「責」に丸傍点］空文庫
    # 責［＃「責」に白丸傍点］空文庫
    # 責［＃「責」に黒三角傍点］空文庫
    # 責［＃「責」に白三角傍点］空文庫
    # 責［＃「責」に二重丸傍点］空文庫
    # 責［＃「責」に蛇の目傍点］空文庫

    # 範囲傍点 FIXME
    # ［＃傍点］青空文庫で読書しよう［＃傍点終わり］
    # ［＃白ゴマ傍点］青空文庫で読書しよう［＃白ゴマ傍点終わり］。
    # ［＃丸傍点］青空文庫で読書しよう［＃丸傍点終わり］。
    # ［＃白丸傍点］青空文庫で読書しよう［＃白丸傍点終わり］。
    # ［＃黒三角傍点］青空文庫で読書しよう［＃黒三角傍点終わり］。
    # ［＃白三角傍点］青空文庫で読書しよう［＃白三角傍点終わり］。
    # ［＃二重丸傍点］青空文庫で読書しよう［＃二重丸傍点終わり］。
    # ［＃蛇の目傍点］青空文庫で読書しよう［＃蛇の目傍点終わり］。

    # 左に傍点 FIXME
    # 責［＃「責」の左に傍点］空文庫
    # 責［＃「責」の左に白ゴマ傍点］空文庫
    # 責［＃「責」の左に丸傍点］空文庫
    # 責［＃「責」の左に白丸傍点］空文庫
    # 責［＃「責」の左に黒三角傍点］空文庫
    # 責［＃「責」の左に白三角傍点］空文庫
    # 責［＃「責」の左に二重丸傍点］空文庫
    # 責［＃「責」の左に蛇の目傍点］空文庫

    # 左に範囲傍点 FIXME
    # ［＃左に傍点］青空文庫で読書しよう［＃左に傍点終わり］。　←　※以下は、新しい記法です。
    # ［＃左に白ゴマ傍点］青空文庫で読書しよう［＃左に白ゴマ傍点終わり］。
    # ［＃左に丸傍点］青空文庫で読書しよう［＃左に丸傍点終わり］。
    # ［＃左に白丸傍点］青空文庫で読書しよう［＃左に白丸傍点終わり］。
    # ［＃左に黒三角傍点］青空文庫で読書しよう［＃左に黒三角傍点終わり］。
    # ［＃左に白三角傍点］青空文庫で読書しよう［＃左に白三角傍点終わり］。
    # ［＃左に二重丸傍点］青空文庫で読書しよう［＃左に二重丸傍点終わり］。
    # ［＃左に蛇の目傍点］青空文庫で読書しよう［＃左に蛇の目傍点終わり］。
  end # }}}

  # 傍線 {{{
  def test_kyouchou_bousen
    # 傍線
    ts = Parser.parse("今日のところはねこを［＃「ねこ」は傍線］なめたい")
    assert_equal Tree::Line.new([Tree::Text.new('ねこ')]),   ts[1]

    # 各種傍線 FIXME
    # 責［＃「責」に傍線］空文庫
    # 責［＃「責」に二重傍線］空文庫
    # 責［＃「責」に鎖線］空文庫
    # 責［＃「責」に破線］空文庫
    # 責［＃「責」に波線］空文庫

    # ［＃傍線］青空文庫で読書しよう［＃傍線終わり］。　←　※以下は、新しい記法です。
    # ［＃二重傍線］青空文庫で読書しよう［＃二重傍線終わり］。
    # ［＃鎖線］青空文庫で読書しよう［＃鎖線終わり］。
    # ［＃破線］青空文庫で読書しよう［＃破線終わり］。
    # ［＃波線］青空文庫で読書しよう［＃波線終わり］。
    #
    # 責［＃「責」の左に傍線］空文庫
    # 責［＃「責」の左に二重傍線］空文庫
    # 責［＃「責」の左に鎖線］空文庫
    # 責［＃「責」の左に破線］空文庫
    # 責［＃「責」の左に波線］空文庫
    #
    # ［＃左に傍線］青空文庫で読書しよう［＃左に傍線終わり］。　←　※以下は、新しい記法です。
    # ［＃左に二重傍線］青空文庫で読書しよう［＃左に二重傍線終わり］。
    # ［＃左に鎖線］青空文庫で読書しよう［＃左に鎖線終わり］。
    # ［＃左に破線］青空文庫で読書しよう［＃左に破線終わり］。
    # ［＃左に波線］青空文庫で読書しよう［＃左に波線終わり］。
  end # }}}

  # 傍線 - 不正？ {{{
  def test_kyouchou_bousen__invalid
    return # FIXME
    ts = Parser.parse('あの美しい猫《ねこ》［＃「猫《ねこ》」に傍線］はなんだろう。')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('あの美しい'),
          Tree::Line.new(
            [
              Tree::Ruby.new([Tree::Text.new('猫')], 'ねこ')
            ]
          ),
          Tree::Text.new('はなんだろう。'),
        ]
      )
    assert_equal expected, ts
  end # }}}

  # 太字(ゴシック) {{{
  def test_kyouchou_bold
    ts = Parser.parse("今日のところはねこ［＃「ねこ」は太字］をなめたい")

    assert_equal 3, ts.size
    assert_instance_of Tree::Text,              ts[0]
    assert_instance_of Tree::Bold,              ts[1]
    assert_instance_of Tree::Text,              ts[2]
    assert_equal       'をなめたい',            ts[2].text

    bold = ts[1]
    assert_equal 1, bold.size
    assert_instance_of Tree::Text,  bold[0]
    assert_equal       'ねこ',      bold.text
    assert_equal       'ねこ',      bold[0].text

    # 範囲 FIXME
  end # }}}

  # 斜体(イタリック) FIXME {{{
  def test_kyouchou_italic
  end # }}}

  # }}}

  # 画像 {{{
  # http://kumihan.aozora.gr.jp/graphics.html

  # 標準 FIXME {{{
  def test_gazou
    # ［＃石鏃二つの図（fig42154_01.png、横321×縦123）入る］
    # ［＃「第一七圖　國頭郡今歸仁村今泊阿應理惠按司勾玉」のキャプション付きの図（fig4990_07.png、横321×縦123）入る］
    # ［＃石鏃二つの図（fig42154_01.png）入る］
  end # }}}

  # 非標準 {{{
  def test_gazou__invalid
    ts = Parser.parse <<-EOT
あいうえお
<img src="img/00.jpg">
さしすせそ
EOT
    assert_equal Tree::Image.new('img/00.jpg'),   ts[2]
  end # }}}

  # }}}

  # その他 {{{
  # http://kumihan.aozora.gr.jp/etc.html

  # 訂正と「ママ」 FIXME {{{
  def test_misc_fix
  end # }}}

  # ルビとルビのように付く文字 {{{
  def test_misc_ruby
    # 単純な例
    ts = Lexer.lex("猫《ねこ》")
    assert_equal 2, ts.size
    assert_instance_of Token::Kanji,              ts[0]
    assert_equal       '猫',                      ts[0].text
    assert_instance_of Token::Ruby,               ts[1]
    assert_equal       'ねこ',                    ts[1].ruby

    # 文章の中
    ts = Parser.parse <<EOT
Hello
吾輩は猫《ねこ》であるぜよ。
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('吾輩は'),
          Tree::Ruby.new([Tree::Text.new('猫')], 'ねこ'),
          Tree::Text.new('であるぜよ。'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # 縦線で区切られたもの
    ts = Parser.parse <<EOT
Hello
吾輩は｜超かわいい生命体《ねこ》であるぜよ。
World
EOT
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('Hello'),
          Tree::LineBreak.new,
          Tree::Text.new('吾輩は'),
          Tree::Ruby.new([Tree::Text.new('超かわいい生命体')], 'ねこ'),
          Tree::Text.new('であるぜよ。'),
          Tree::LineBreak.new,
          Tree::Text.new('World'),
          Tree::LineBreak.new
        ]
      )
    assert_equal expected, ts

    # 注記にたいしてルビがふってあるもの
    ts = Parser.parse('碍子を※［＃「てへん＋丑」、第4水準2-12-93］《ね》じこんだり')
    expected =
      Tree::Document.new(
        [
          Tree::Text.new('碍子を'),
          Tree::Ruby.new(
            [Tree::JIS.new([Tree::Text.new('※')], 'てへん＋丑」、第4水準2-12-93')],
            'ね'
          ),
          Tree::Text.new('じこんだり')
        ]
      )
    assert_equal expected, ts

    # 左につく FIXME
    # 青空文庫［＃「青空文庫」の左に「あおぞらぶんこ」のルビ］
  end # }}}

  # 縦組み中で横に並んだ文字 {{{
  def test_misc_yoko
    ts = Parser.parse("今日のところはねこを［＃「ねこ」は縦中横］なめたい")
    assert_equal Tree::Yoko.new([Tree::Text.new('ねこ')]),   ts[1]

    # 範囲 FIXME
    #［＃縦中横］（※［＃ローマ数字1、1-13-21］）［＃縦中横終わり］
  end # }}}

  # 割り注 FIXME {{{
  def test_misc_warichu
  end # }}}

  # 行右小書き、行左小書き文字（縦組み） FIXME {{{
  def test_misc_kogaki_tate
  end # }}}

  # 上付き小文字、下付き小文字（横組み） FIXME {{{
  def test_misc_kogaki_yoko
  end # }}}

  # 罫囲み FIXME {{{
  def test_misc_border_line
  end # }}}

  # 横組みの底本 FIXME {{{
  def test_misc_yokogumi_book
  end # }}}

  # 縦組み本文中の横組み FIXME {{{
  def test_misc_yokogumi
  end # }}}

  # 文字サイズ FIXME {{{
  def test_misc_char_size
  end # }}}

  # }}}

  # 注記の重複 FIXME {{{
  # }}}

  # 青空文庫を越えた利用（番外）# {{{
  #   本文終わり
  #   青空文庫ファイルで使えない文字
  #     ルビ記号など、特別な役割を与えられた文字
  #     外字注記形式による代替表現
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
