# Last Modified: 2017.07.13 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'highline'
require 'inflecto'
require 'singleton'
require 'whirly'

module MrMurano
  # Progress is a singleton (evil!) that implements a terminal progress bar.
  class Progress
    include Singleton

    def initialize
      @whirly_msg = ''
      @whirly_time = nil
      @whirly_users = 0
      @whirly_cols = 0
      @whirly_paused = false
    end

    EXO_QUADRANTS = [
      '▚',
      '▘',
      '▝',
      '▞',
      '▖',
      '▗',
    ].freeze

    def whirly_start(msg)
      say msg if $cfg['tool.verbose']
      return if $cfg['tool.no-progress']
      # Count the number of calls to whirly_start, so that the
      # first call to whirly_start is the message that gets
      # printed. This way, methods can define a default message
      # to use, but then callers of those methods can choose to
      # display a different message.
      @whirly_users = 0 unless defined?(@whirly_users)
      @whirly_users += 1
      # The first Whirly message is the one we show.
      return if @whirly_users > 1
      @whirly_msg = msg
      whirly_stop
      whirly_show
    end

    def whirly_show
      Whirly.start(
        spinner: EXO_QUADRANTS,
        status: @whirly_msg,
        append_newline: false,
      )
      @whirly_time = Time.now
      @whirly_cols, _rows = HighLine::SystemExtensions.terminal_size
    end

    def whirly_stop(force: false)
      return if $cfg['tool.no-progress'] || !defined?(@whirly_time)
      if force
        @whirly_users = 0
      else
        @whirly_users -= 1
      end
      return unless @whirly_users.zero?
      whirly_linger
      whirly_clear
    end

    def whirly_clear
      Whirly.stop
      # The progress indicator is always overwritten.
      return unless @whirly_cols
      $stdout.print((' ' * @whirly_cols) + "\r")
      $stdout.flush
    end

    def whirly_linger
      return if $cfg['tool.no-progress'] || !defined?(@whirly_time)
      not_so_fast = 0.55 - (Time.now - @whirly_time)
      remove_instance_variable(:@whirly_time)
      sleep(not_so_fast) if not_so_fast > 0
    end

    def whirly_msg(msg)
      return if $cfg['tool.no-progress']
      if defined?(@whirly_time)
        @whirly_msg = msg
        #self.whirly_linger
        Whirly.configure(status: @whirly_msg)
      else
        whirly_start msg
      end
    end

    def whirly_pause
      return if defined?(@whirly_paused) && @whirly_paused
      return if !defined?(@whirly_users) || @whirly_users.zero?
      @whirly_paused = true
      whirly_clear
    end

    def whirly_unpause
      return if !defined?(@whirly_paused) || !@whirly_paused
      @whirly_paused = false
      whirly_show
    end
  end
end

