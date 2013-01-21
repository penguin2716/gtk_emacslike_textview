#-*- coding: utf-8 -*-
require 'gtk2'
require 'gtksourceview2'

module Gtk
  class EmacsLikeTextView < Gtk::SourceView

# @@hist_limit            : 履歴スタックの最大保存数
# @@control_targetkey     : Ctrlで装飾してEmacsっぽいキーバインドにするキー．
#                           元から割り当てられていた機能は呼ばない．
# @@control_unselectkey   : 選択トグルを自動的にOFFにするキー
# @@post_history          : ポスト履歴を保存するグローバルスタック
# @@post_history_ptr      : ポスト履歴のスタックポインタ
# @default_basecolor      : デフォルトの背景色
# @default_fgcolor        : デフォルトの文字色
# @alternate_basecolor    : 文字数が閾値を上回った場合に設定する背景色
# @alternate_fgcolor      : 文字数が閾値を上回った場合に設定する文字色
# @color_change_count     : 背景色を変更する文字数の閾値．nilに設定すると背景色を変更しない
# @select                 : 選択トグルのON/OFFを格納
# @history_stack          : 履歴スタック
# @stack_ptr              : 履歴スタックポインタ
# @isundo                 : undoによる変更かどうかの確認

    @@hist_limit = 8000
    @@control_targetkey = ['A', 'space', 'g', 'f', 'b', 'n', 'p', 'a',
                   'e', 'd', 'h', 'w', 'k', 'y', 'slash', 'z']
    @@control_unselectkey = ['g', 'd', 'h', 'w', 'k', 'y', 'slash', 'z']
    @@mod1_targetkey = ['f', 'b', 'a', 'e', 'w', 'd', 'h', 'n', 'p']
    @@mod1_unselectkey = ['w', 'd', 'h', 'n', 'p']

    @@post_history = []
    @@post_history_ptr = 0

    def self.pushGlobalStack(text)
      @@post_history_ptr = @@post_history.length
      @@post_history.push(text) end


    def add_signal(buffer)
      buffer.signal_connect('changed') {
        if not @isundo then
          @history_stack += @history_stack[@stack_ptr..-2].reverse
          self.push_buffer
          @stack_ptr = @history_stack.length - 1
        end

        if UserConfig[:etv_change_background_color]
        # 文字数に応じて背景色を変更
          if get_color_change_count != nil
            if self.buffer.text.length > get_color_change_count
              self.modify_base(Gtk::STATE_NORMAL, self.alternate_basecolor)
              self.modify_text(Gtk::STATE_NORMAL, self.alternate_fgcolor)
            else
              self.modify_base(Gtk::STATE_NORMAL, self.default_basecolor)
              self.modify_text(Gtk::STATE_NORMAL, self.default_fgcolor)
            end
          end
        end
      }
      buffer
    end

    # ハイライトする言語の変更
    def update_language(lang)
      buffer = add_signal(Gtk::SourceBuffer.new)

      lang_manager = Gtk::SourceLanguageManager.new
      language = lang_manager.get_language(lang)
      if language != nil
        set_color_change_count(nil)
        self.auto_indent = true
        self.highlight_current_line = true
      else
        set_color_change_count(140)
        self.auto_indent = false
        self.highlight_current_line = false
      end
      buffer.language = language
      self.buffer = buffer
    end

    def update_language_post
      if self.buffer.text =~ /^@@[a-z]+$/
        lang = self.buffer.text.sub(/^@@/,'')
        update_language(lang)
      end
    end

    def get_snippets
      return @snippets if defined?(@snippets)
      @snippets = []
      load_path = ['../plugin', '~/.mikutter/plugin']
      load_path.each { |path|
        snippets = `find #{path} | grep snippets/`.split("\n")
        snippets.select!{ |candidate| File.file?(candidate) }
        snippets.each { |snippet|
          f = open(snippet, "r")
          @snippets << [File.basename(snippet), f.read.sub(/[\n]+$/,'')]
          f.close
        }
      }
      @snippets
    end

    def expand_snippet
      complete = false
      get_snippets.each do |pattern, completion|
        index = self.buffer.text.index(pattern)
        while index
          lastindex = index
          if index + pattern.size == self.buffer.cursor_position
            self.delete_from_cursor(Gtk::DELETE_CHARS, -1 * pattern.size)
            auto_pos = completion.index('$0')
            if auto_pos
              completion.sub!('$0', '')
              self.buffer.insert_at_cursor(completion)
              self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, -1 * completion[auto_pos..-1].size, @select)
              
            else
              self.buffer.insert_at_cursor(completion)
            end
            complete = true
            break
          else
            index = self.buffer.text.index(pattern, lastindex + 1)
          end
        end
      end
      complete
    end

    def initialize
      super
      @select = false
      @history_stack = []
      @history_stack.push(self.buffer.text)
      @stack_ptr = 0
      @isundo = false

      # 行数を表示，言語は未設定
      self.show_line_numbers = true
      update_language('')

      # バッファが変更されたら自動的に履歴スタックに積む
      add_signal(self.buffer)

      # キーバインドの追加
      self.signal_connect('key_press_event') { |w, e|
        if Gdk::Window::ModifierType::CONTROL_MASK ==
            e.state & Gdk::Window::CONTROL_MASK and
            Gdk::Keyval.to_name(e.keyval) == 'slash' then
          @isundo = true
        else
          @isundo = false
        end

        # Tabフォーカスをフック
        if Gdk::Window::ModifierType::SHIFT_MASK ==
            e.state & Gdk::Window::SHIFT_MASK and
            Gdk::Keyval.to_name(e.keyval) == 'ISO_Left_Tab'
          @select = false
          if UserConfig[:shortcutkey_keybinds].select{ |key, bind|
              bind[:slug] == :expand_snippet and bind[:key] == 'Shift + ISO_Left_Tab'
            } != {}
            unless expand_snippet
              move_focus(Gtk::DIR_TAB_BACKWARD)
            end
          else
            move_focus(Gtk::DIR_TAB_BACKWARD)
          end
          true

        elsif Gdk::Keyval.to_name(e.keyval) == 'Tab'
          @select = false
          if UserConfig[:shortcutkey_keybinds].select{ |key, bind|
              bind[:slug] == :expand_snippet and bind[:key] == 'Tab'
            } != {}
            unless expand_snippet
              move_focus(Gtk::DIR_TAB_FORWARD)
            end
          else
            move_focus(Gtk::DIR_TAB_FORWARD)
          end
          true

        # Mod1 による装飾
        elsif Gdk::Window::ModifierType::MOD1_MASK ==
            e.state & Gdk::Window::MOD1_MASK then
          key = Gdk::Keyval.to_name(e.keyval)

          # 選択トグルの解除
          if @@mod1_unselectkey.select{|k| k == key}.length > 0 then
            @select = false
          end

          case key
          when 'f'
            self.move_cursor(Gtk::MOVEMENT_WORDS, 1, @select)
          when 'b'
            self.move_cursor(Gtk::MOVEMENT_WORDS, -1, @select) 
          when 'a'
            self.move_cursor(Gtk::MOVEMENT_BUFFER_ENDS, -1, @select )
          when 'e'
            self.move_cursor(Gtk::MOVEMENT_BUFFER_ENDS, 1, @select )
          when 'd'
            delete_from_cursor(Gtk::DELETE_WORD_ENDS, 1)
          when 'h'
            delete_from_cursor(Gtk::DELETE_WORD_ENDS, -1)
          when 'w'
            self.copy_clipboard
            self.select_all(false)
          when 'n'
            redoGlobalStack
          when 'p'
            undoGlobalStack
          end
          
          # Emacsっぽいキーバインドとして実行したら，もとから割り当てられていた機能は呼ばない
          if @@mod1_targetkey.select{|k| k == key}.length > 0 then
            true
          else
            false
          end

        # Control による装飾
        elsif Gdk::Window::ModifierType::CONTROL_MASK ==
            e.state & Gdk::Window::CONTROL_MASK then
          key = Gdk::Keyval.to_name(e.keyval)

          # 選択トグルの解除
          if @@control_unselectkey.select{|k| k == key}.length > 0 then
            @select = false
          end

          case key
          when 'A' # 全選択
            self.select_all(true)
          when 'space' # 選択トグルのON/OFF
            if @select then
              @select = false
            else
              @select = true
            end
          when 'g' # 選択解除
            self.select_all(false)
          when 'f' # 右に移動
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, 1, @select)
          when 'b' # 左に移動
            self.move_cursor(Gtk::MOVEMENT_VISUAL_POSITIONS, -1, @select)
          when 'n' # 次の行に移動
            self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, 1, @select)
          when 'p' # 前の行に移動
            self.move_cursor(Gtk::MOVEMENT_DISPLAY_LINES, -1, @select)
          when 'a' # 行頭へ移動
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, -1, @select)
          when 'e' # 行末へ移動
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, 1, @select)
          when 'd' # Deleteの挙動
            self.delete_from_cursor(Gtk::DELETE_CHARS, 1)
          when 'h' # BackSpaceの挙動
            self.delete_from_cursor(Gtk::DELETE_CHARS, -1)
          when 'w' # カット
            self.cut_clipboard
          when 'k' # 現在位置から行末までカット．行末の場合はDeleteの挙動になる
            before = self.buffer.text
            self.move_cursor(Gtk::MOVEMENT_PARAGRAPH_ENDS, 1, true)
            self.cut_clipboard
            if before == self.buffer.text then
              self.delete_from_cursor(Gtk::DELETE_CHARS, 1)
            end
          when 'y' # 現在位置に貼り付け
            self.paste_clipboard
          when 'slash', 'z' # undoの挙動
            self.undo
          end

          # Emacsっぽいキーバインドとして実行したら，もとから割り当てられていた機能は呼ばない
          if @@control_targetkey.select{|k| k == key}.length > 0 then
            true
          else
            false
          end

        end

      }
    end

    def set_color_change_count(count)
      @color_change_count = count
    end

    def get_color_change_count
      @color_change_count
    end

    def default_basecolor
      color = UserConfig[:etv_default_background_color]
      @default_basecolor = Gdk::Color.new(color[0], color[1], color[2])
      @default_basecolor
    end

    def alternate_basecolor
      color = UserConfig[:etv_alternate_background_color]
      @alternate_basecolor = Gdk::Color.new(color[0], color[1], color[2])
      @alternate_basecolor
    end

    def default_fgcolor
      color = UserConfig[:etv_default_foreground_color]
      @default_fgcolor = Gdk::Color.new(color[0], color[1], color[2])
      @default_fgcolor
    end

    def alternate_fgcolor
      color = UserConfig[:etv_alternate_foreground_color]
      @alternate_fgcolor = Gdk::Color.new(color[0], color[1], color[2])
      @alternate_fgcolor
    end

    # 現在のバッファと最新の履歴が異なっていればスタックに現在の状態を追加
    def push_buffer
      if @history_stack == nil then
        @history_stack = ['']
      end
      if self.buffer.text != '' then
        if @history_stack[-1] != self.buffer.text then
          @history_stack.push(self.buffer.text)
        end
        if @history_stack.length > @@hist_limit then
          @history_stack = @history_stack[(@history_stack.length - @@hist_limit)..-1]
        end
      end
    end

    # undoの実装．バッファの内容を変更すると自動的に履歴スタックに追加されるので，
    # 履歴スタックに追加したら最新の履歴を捨てる
    def undo
      top = @history_stack[@stack_ptr]
      if top != nil then
        if top == self.buffer.text then
          # 最新履歴が現在の状態と同じなら，2番目の履歴を参照
          decStackPtr
          second = @history_stack[@stack_ptr]
          if second != nil then
            self.buffer.set_text(second)
          else # 上から2番目が空
            self.buffer.set_text('')
          end
        else
          self.buffer.set_text(top)
        end
      else # 履歴スタックが空
        self.buffer.set_text('')
      end
    end

    def incStackPtr
      if @history_stack.length > @stack_ptr + 1 then
        @stack_ptr += 1
      end
    end

    def decStackPtr
      if @stack_ptr > 0 then
        @stack_ptr -= 1
      end
    end

    # 初期状態にリセットする．現在は使っていない
    def reset
      @history_stack = []
      @select = false
    end

    def undoGlobalStack
      if @@post_history != []
        self.buffer.set_text(@@post_history[@@post_history_ptr])
        @@post_history_ptr = (@@post_history_ptr - 1) % @@post_history.length
      end
    end

    def redoGlobalStack
      if @@post_history != []
        self.buffer.set_text(@@post_history[@@post_history_ptr])
        @@post_history_ptr = (@@post_history_ptr + 1) % @@post_history.length
      end
    end

  end
end

class Gtk::PostBox
  def gen_widget_post
    Gtk::EmacsLikeTextView.new end end

