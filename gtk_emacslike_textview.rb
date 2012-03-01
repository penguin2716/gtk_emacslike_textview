#-*- coding: utf-8 -*-
require 'gtk2'

module Gtk
  class EmacsLikeTextView < Gtk::TextView

# @@hist_limit    : 履歴スタックの最大保存数
# @@control_targetkey     : Ctrlで装飾してEmacsっぽいキーバインドにするキー．
#                   元から割り当てられていた機能は呼ばない．
# @@control_unselectkey   : 選択トグルを自動的にOFFにするキー．
# @select         : 選択トグルのON/OFFを格納
# @history_stack          : 履歴スタック

    @@hist_limit = 100
    @@control_targetkey = ['A', 'space', 'g', 'f', 'b', 'n', 'p', 'a',
                   'e', 'd', 'h', 'w', 'k', 'y', 'slash', 'z']
    @@control_unselectkey = ['g', 'd', 'h', 'w', 'k', 'y', 'slash', 'z']
    @@mod1_targetkey = ['f', 'b', 'a', 'e', 'w']
    @@mod1_unselectkey = ['w']

    def initialize
      super
      @select = false
      @history_stack = []
      @history_stack.push(self.buffer.text)

      # バッファが変更されたら自動的に履歴スタックに積む
      self.buffer.signal_connect('changed') {
        self.push_buffer
      }

      # キーバインドの追加
      self.signal_connect('key_press_event') { |w, e|
        if Gdk::Window::ModifierType::MOD1_MASK ==
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
          when 'w'
            self.copy_clipboard
            self.select_all(false)
          end
          
          # Emacsっぽいキーバインドとして実行したら，もとから割り当てられていた機能は呼ばない
          if @@mod1_targetkey.select{|k| k == key}.length > 0 then
            true
          else
            false
          end

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

    # 現在のバッファと最新の履歴が異なっていればスタックに現在の状態を追加
    def push_buffer
      if @history_stack == nil then
        @history_stack = ['']
      end
      if self.buffer.text != '' then
        if @history_stack[-1] != self.buffer.text then
          @history_stack.push(self.buffer.text)
        end
        if @history_stack.size > @@hist_limit then
          @history_stack.delete(@history_stack[0])
        end
      end
    end

    # undoの実装．バッファの内容を変更すると自動的に履歴スタックに追加されるので，
    # 履歴スタックに追加したら最新の履歴を捨てる
    def undo
      top = @history_stack[-1]
      if top != nil then
        if top == self.buffer.text then
          # 最新履歴が現在の状態と同じなら，2番目の履歴を参照
          @history_stack.pop
          second = @history_stack.pop
          if second != nil then
            self.buffer.set_text(second)
            @history_stack.pop
          else # 上から2番目が空
            self.buffer.set_text('')
            @history_stack.pop
          end
        else
          self.buffer.set_text(top)
          @history_stack.pop
        end
      else # 履歴スタックが空
        self.buffer.set_text('')
        @history_stack.pop
      end
    end

    # 初期状態にリセットする．現在は使っていない
    def reset
      @history_stack = []
      @select = false
    end

  end
end
