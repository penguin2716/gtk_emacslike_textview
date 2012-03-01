#!/usr/bin/env ruby
#-*- coding: utf-8 -*-
require 'gtk2'
require './gtk_emacslike_textview.rb'

etv = Gtk::EmacsLikeTextView.new

window = Gtk::Window.new
window.signal_connect('key_press_event') { |w, e|
  if Gdk::Keyval.to_name(e.keyval) == 'q' then
    Gtk.main_quit
  end
}
window.signal_connect('destroy') {
  Gtk.main_quit
}
window.add(etv)
etv.show
etv.buffer.text = '''以下のようなことができます
・C-[fbnpae]  カーソルの移動
・C-[dh]      文字の削除
・C-SPC       選択のトグル
・C-[/z]      戻る
・C-w         選択領域のカット
・C-k         行末までカット
・C-y         カーソル位置に貼り付け
・C-g         選択のトグルをOFF
・C-A         全選択'''
window.show
window.set_size_request(300,200)

Gtk.main
