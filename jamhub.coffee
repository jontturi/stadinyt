J = {}

global = (typeof exports == "undefined" && window || exports)
global.J = J

$ = global.$ || { easing: {}, fn: {} }
_ = global._ || { template: -> }
moment = global.moment || require "moment"

$.easing.easeInOutQuad = (x, t, b, c, d) ->
  return c/2*t*t + b if ((t/=d/2) < 1)
  return -c/2 * ((--t)*(t-2) - 1) + b

$.fn.draggable = (opts={}) ->
  touch_enabled = 'ontouchstart' of document

  # TODO: add touchstart, etc
  body = $ document.body
  html = $ "html"

  mouse_x = 0
  mouse_y = 0

  drag_stop = (e) =>
    body.removeClass "dragging"
    @removeClass "dragging"
    html.off "mousemove touchmove", drag_move
    opts.stop?()

  drag_move = (e, _x, _y) =>
    dx = _x - mouse_x
    dy = _y - mouse_y
    mouse_x += dx
    mouse_y += dy
    opts.move? dx, dy

  drag_start = (e, _x, _y) =>
    return if body.is ".dragging"
    return if opts.skip_drag? e

    body.addClass "dragging"
    @addClass "dragging"
    mouse_x = _x
    mouse_y = _y
    opts.start?()
    true

  # start, stop, move
  if touch_enabled
    @on "touchstart", (e) =>
      {pageX: x, pageY: y } = e.originalEvent.targetTouches[0]
      if drag_start e, x, y
        html.one "touchend", drag_stop

        drag_move = do (move=drag_move) =>
          (e) =>
            {pageX: x, pageY: y } = e.originalEvent.targetTouches[0]
            move e, x, y

        html.on "touchmove", drag_move

        false
  else
    @on "mousedown", (e) =>
      if drag_start e, e.pageX, e.pageY
        html.one "mouseup", drag_stop

        drag_move = do (move=drag_move) =>
          (e) => move e, e.pageX, e.pageY

        html.on "mousemove", drag_move


J.parse_jam_timestamp = do ->
  patterns = [
    "YYYY-MM-DD HH:mm:ss Z"
    "YYYY-MM-DD HH:mm Z"
    "YYYY-MM-DD"
  ]

  loose_patterns = {
    "YYYY-MM-DD": true
  }

  (timestamp) ->
    for p in patterns
      d = moment timestamp, p, true
      break if d.isValid()

      d = moment "#{timestamp} +0000", p, true
      break if d.isValid()

    [d.isValid() && d.toDate(), loose_patterns[p]]

J.slugify = (str) ->
  str.toLowerCase()
    .replace(/\+/g, " plus ")
    .replace(/\s+/g, "-")
    .replace(/[^\w-]+/g, "")
    .replace(/--+/g, "-")
    .replace(/^-/, "")
    .replace(/-$/, "")

class J.Jams
  # get all active jam.json
  @jam_urls: ->
    today = moment()
    start_year = today.subtract("month", 1).get "year"
    end_year = today.add("month", 2).get "year"

    urls = ["jams/" + start_year + ".json"]
    if end_year != start_year
      urls.push "jams/" + end_year + ".json"

    urls

  @fetch: (fn) ->
    urls = @jam_urls()
    @_deferred ||= $.when(($.get(url) for url in urls)...).then =>
      all_jams = []
      if urls.length > 1
        for res in arguments
          all_jams = all_jams.concat res[0].jams
      else
        all_jams = arguments[0].jams

      @slugify_jams all_jams
      new J.Jams all_jams

    @_deferred.done fn

  @slugify_jams: (jams, jams_by_slug={}) ->
    for jam in jams
      jam.slug = J.slugify jam.name
      [start_date] = J.parse_jam_timestamp jam.start_date
      start_date = moment start_date

      # name taken
      if jams_by_slug[jam.slug]
        jam.slug += "-#{start_date.year()}-#{start_date.format("MMMM")}".toLowerCase()

      # name still taken, add day
      if jams_by_slug[jam.slug]
        jam.slug += "-#{start_date.date()}".toLowerCase()

      if jams_by_slug[jam.slug]
        throw "jam name still taken"

      jams_by_slug[jam.slug] = jam
      jam.local_url = "jams/#{start_date.year()}/#{jam.slug}"

      if jam.tags
        for i of jam.tags
          jam.tags[i] = J.slugify jam.tags[i]

    jams_by_slug

  constructor: (data) ->
    @jams = for jam_data in data
      new J.Jam jam_data

  truncate: (time) ->
    @jams = _.reject @jams, (jam) => jam.end_date() < time

  find_in_progress: ->
    _.filter @jams, (jam) => jam.in_progress()

  find_in_before_start: ->
    _.filter @jams, (jam) => jam.before_start()

  find_in_range: (start, end) ->
    _.filter @jams, (jam) => jam.collides_with start, end

class J.Jam
  box_tpl: _.template """
    <div class="jam_box<% if (image) { %> has_image<% }%>">
      <% if (image) { %>
        <a href="<%- url %>">
          <div class="cover_image" style="background-image: url(<%- image %>)"></div>
        </a>
      <% } %>

      <h3>
        <% if (url) { %>
          <a href="<%- url %>"><%- name %></a>
        <% } else { %>
          <%- name %>
        <% }%>
      </h3>

      <% if (url) { %>
        <p class="jam_link">
           <a href="<%- url %>"><%- url %></a>
        </p>
      <% }%>
      <p><%- description %></p>
      <%= time_data %>
    </div>
  """

  in_progress_tpl: _.template """
    <div class="progress_outer">
      <div class="time_labels">
        <div class="left_label"><%- start_label %></div>
        <div class="right_label"><%- end_label %></div>
      </div>

      <div class="progress">
        <div class="progress_inner" style="width: <%= percent_complete  %>%"></div>
      </div>

      <div class="remaining_label"><%- remaining_label %> left</div>
    </div>
  """

  time_tpl: _.template """
    <div class="time_data">
      <p><%= time_label %></p>
    </div>
  """

  calendar_template: _.template """
    <div class="jam_cell" data-slug="<%- slug %>">
      <span class="fixed_label">
        <a href="<%- local_url %>"><%- name %></a>
      </span>
    </div>
  """

  constructor: (@data) ->

  length: ->
    @end_date() - @start_date()

  render_for_calendar: ->
    $(@calendar_template @data)
      .data("jam", @)
      .toggleClass("after_end", @after_end())

  render: ->
    tags = [].concat(@data.themes || []).concat(@data.tags || [])
    $ @box_tpl $.extend { image: false }, @data, {
      tags: tags
      time_data: @render_time_data()
    }

  render_time_data: ->
    if @in_progress()
      progress = (new Date() - @start_date()) / (@end_date() - @start_date())
      @in_progress_tpl {
        percent_complete: Math.floor progress * 100
        start_label: @date_format @start_date(), "start"
        end_label: @date_format @end_date(), "end"
        remaining_label: moment(@end_date()).fromNow true
      }
    else if @before_start()
      relative = moment(@start_date()).fromNow true
      begin = @date_format @start_date(), "start"
      end = @date_format @end_date(), "end"

      @time_tpl {
        time_label: "Starts in #{relative} &middot; <strong>#{begin}</strong> to <strong>#{end}</strong>"
      }
    else if @after_end()
      @time_tpl {
        time_label: "Ended #{moment(@end_date()).fromNow true} ago"
      }

  date_format: (date, name) ->
    is_loose = @["_#{name}_date_loose"]

    f = "ll"
    f = "#{f} H:mm" unless is_loose
    moment(date).format(f)

  collides_with: (range_start, range_end) ->
    return false if +@start_date() > +range_end
    return false if +@end_date() < +range_start
    true

  in_progress: ->
    now = +new Date()
    now >= +@start_date() && now <= +@end_date()

  before_start: ->
    now = +new Date()
    now < +@start_date()

  after_end: ->
    now = +new Date()
    now > +@end_date()

  start_date: ->
    unless @_start_date
      [@_start_date, @_start_date_loose] = J.parse_jam_timestamp @data.start_date
    @_start_date

  end_date: ->
    unless @_end_date
      [@_end_date, @_end_date_loose] = J.parse_jam_timestamp @data.end_date
      if @_end_date_loose
        @_end_date = moment(@_end_date).endOf("day").toDate()

    @_end_date

  share_message: =>
    "#{@data.name} - #{@date_format @start_date()} to #{@date_format @end_date()} #stadinyt"

class J.List
  constructor: (el) ->
    J.list = @
    @el = $ el

    J.Jams.fetch (@jams) =>
      @render_in_progress()
      @render_upcoming()

  render_in_progress: ->
    jams = @jams.find_in_progress()
    return unless jams.length

    @el.append "<h2>Events in progress</h2>"
    jams.sort (a,b) ->
      a_remaining = +new Date() - +a.start_date()
      b_remaining = +new Date() - +b.start_date()
      a_remaining - b_remaining

    for jam in jams
      @el.append jam.render()

  render_upcoming: ->
    jams = @jams.find_in_before_start()

    return unless jams.length

    @el.append "<h2>Upcoming events</h2>"

    jams.sort (a,b) ->
      a.start_date() - b.start_date()

    # remove dupes
    seen = {}
    jams = for jam in jams
      continue if seen[jam.data.name]
      seen[jam.data.name] = true
      jam

    for jam in jams
      @el.append jam.render()

  show_jam: (jam) ->
    new_jam = jam.render()
      .addClass("current_jam")

    if @current
      @current.fadeOut =>
        @el.find(".current_jam").remove()
        new_jam.prependTo(@el)
          .hide()
          .fadeIn()
    else
      new_jam.prependTo(@el)
        .hide()
        .slideDown()

    @current = new_jam

class J.Calendar
  default_color: [149, 52, 58]
  day_width: 120

  constructor: (el) ->
    J.calendar = @
    @el = $ el
    @setup_events()

    J.Jams.fetch (@jams) =>
      @jams.truncate @start_date()

      @render_jams()
      @render_day_markers()
      @render_month_markers()
      @render_elapsed_time()

      @setup_scrollbar()
      @setup_fixed_labels()
      @scroll_to_date new Date()

      @setup_dragging()

      @list = new J.List $ ".jam_list"

  setup_events: ->
    @el.on "click", ".jam_cell a", (e) =>
      target = $(e.currentTarget).closest ".jam_cell"
      jam = target.data "jam"
      @list.show_jam jam
      e.preventDefault()

  setup_scrollbar: ->
    scrollbar_outer = $("""
    <div class="scrollbar_outer">
      <div class="scrollbar"></div>
    </div>
    """).appendTo(@el)

    @scrollbar = scrollbar_outer.find(".scrollbar")
    setTimeout (=> @scrollbar.addClass "visible"), 0

    update_scroll = =>
      left = @calendar.scrollLeft()
      width = @calendar.width()
      inner_width = @scroller.width()

      @scrollbar.css {
        left: "#{Math.floor (left / inner_width) * width}px"
        right: "#{Math.floor ((inner_width - (left + width)) / inner_width) * width}px"
      }

    @calendar.on "scroll", update_scroll
    update_scroll()

  move_calendar: (dx, dy) ->
    @calendar.scrollLeft @calendar.scrollLeft() - dx
    @update_labels?()

  setup_dragging: (el) ->
    @calendar.draggable {
      skip_drag: (e) =>
        return true if $(e.target).closest("a").length

      move: (dx, dy) =>
        @move_calendar dx, dy
    }

    @el.find(".scrollbar").draggable {
      move: (dx, dy) =>
        scale = @scroller.width() / @calendar.width()
        @move_calendar dx * -scale, dy
    }

    @el.on "click", ".scrollbar_outer", (e) =>
      return if $(e.target).is ".scrollbar"
      left = $(e.currentTarget).find(".scrollbar").offset().left
      left_mouse = e.pageX
      width = Math.floor @scroller.width() / 10

      if left_mouse < left
        @move_calendar width, 0
      else
        @move_calendar -width, 0

  setup_fixed_labels: ->
    @update_labels = =>
      viewport_left = @calendar.scrollLeft()
      viewport_right = viewport_left + @calendar.width()

      @fixed_labels ||= ($(el) for el in @calendar.find ".fixed_label")

      for label in @fixed_labels
        parent = label.parent()
        left = parent.position().left
        right = left + parent.width()
        visible = right >= viewport_left && left <= viewport_right
        parent.toggleClass "visible", visible

        label_width = label.outerWidth()

        margin_left = viewport_left - left

        margin_left = if margin_left > 0
          max_right = (right - left) - label_width
          margin_left = Math.min margin_left, max_right
          "#{margin_left}px"
        else
          ""

        label.css "marginLeft", margin_left

    @update_labels()

  # centers on date
  scroll_to_date: (date) ->
    @calendar.animate {
      scrollLeft: @x_scale date - (@calendar.width() / 2 / @x_ratio())
    }, {
      duration: 600
      easing: "easeInOutQuad"
      progress: =>
        @update_labels?()
    }

  # pixels per ms
  x_ratio: ->
    @scroller.width() / (@end_date() - @start_date())

  # date to x coordiante
  x_scale: (date) ->
    Math.floor (date - +@start_date()) * @x_ratio()

  x_scale_truncated: (date) ->
    Math.min @scroller.width(), Math.max 0, @x_scale(date)

  jam_color: (jam, dh=0, ds=0, dl=0) ->
    unless jam.color
      @default_color[0] += 27
      jam.color = [@default_color[0], @default_color[1], @default_color[2]]

    [h,s,l] = jam.color
    s /= 6 if jam.after_end()
    "hsl(#{h + dh}, #{s + ds}%, #{l + dl}%)"

  render_elapsed_time: ->
    el = $("""<div class="elapsed_time"></div>""")
      .css("width", @x_scale(new Date))
      .appendTo @scroller

  render_month_markers: ->
    markers = $("<div class='month_markers'></div>")
      .appendTo(@scroller)

    curr = moment(@start_date())
      .date(1).hours(0).minutes(0).seconds(0).milliseconds(0)

    end = +@end_date()
    while +curr.toDate() < end
      curr_end = curr.clone().add("month", 1)

      left = @x_scale_truncated curr.toDate()
      right = @x_scale_truncated curr_end.toDate()

      marker = $("""
        <div class="month_marker">
          <span class="fixed_label">
            #{curr.format("MMMM")}
          </span>
        </div>
      """)
        .css({
          left: "#{left}px"
          width: "#{right - left}px"
        })
        .appendTo(markers)

      curr = curr_end

  render_day_markers: ->
    day_length = 1000 * 60 * 60 * 24

    markers = $("<div class='day_markers'></div>")
      .appendTo(@scroller)

    curr = moment @start_date()

    end = +@end_date()
    while +curr.toDate() < end
      curr_end = curr.clone().add("day", 1)

      left = @x_scale_truncated curr.toDate()
      right = @x_scale_truncated curr_end.toDate()

      marker = $("""
      <div class='day_marker'>
        <div class='day_ordinal'>#{curr.format "Do"}</div>
        <div class='day_name'>#{curr.format "ddd"}</div>
      </div>
      """)
        .css({
          width: "#{right - left}px"
          left: "#{left}px"
        })
        .appendTo(markers)

      curr = curr_end

  render_jams: ->
    @calendar = @el.find(".calendar")
    unless @calendar.length
      @calendar = $("<div class='calendar'></div>").appendTo(@el)

    @calendar.empty()

    jams = @jams.find_in_range @start_date(), @end_date()
    stacked = @stack_jams jams

    total_days = (@end_date() - @start_date()) / (1000 * 60 * 60 * 24)
    outer_width = @day_width * total_days

    @scroller = $("<div class='calendar_scrolling'></div>")
      .width(outer_width)
      .height(40*3 + 6 + stacked.length * (40+3))
      .appendTo(@calendar)

    rows_el = $("<div class='calendar_rows'></div>")
      .appendTo(@scroller)

    for row in stacked
      row_el = $("<div class='calendar_row'></div>")
        .appendTo(rows_el)

      for jam in row
        left = @x_scale_truncated jam.start_date()
        width = @x_scale_truncated(jam.end_date()) - left

        jam_el = jam.render_for_calendar()
          .appendTo(row_el)
          .css({
            backgroundColor: @jam_color(jam)
            textShadow: "1px 1px 1px #{@jam_color(jam, 0, 0, -10)}"
            left: "#{left}px"
            width: "#{width}px"
          })

        if jam_el.find(".fixed_label").width() > jam_el.width()
          jam_el.addClass "small_text"

  sort_by_length: (jams) ->
    jams.sort (a,b) ->
      b.length() - a.length()

  stack_jams: (jams) ->
    rows = []
    @sort_by_length jams

    for jam in jams
      placed = false

      for row in rows
        collided = false
        for other_jam in row
          collided = jam.collides_with other_jam.start_date(), other_jam.end_date()
          break if collided

        unless collided
          row.push jam
          placed = true
          break

      unless placed
        rows.push [jam]

    rows

  _today: ->
    moment().hours(0).minutes(0).seconds(0).milliseconds(0)

  start_date: ->
    @_today().subtract("month", 1).toDate()

  end_date: ->
    @_today().add("month", 2).toDate()

class J.Header
  constructor: (el) ->
    @constructor.instance = @

    @el = $ el
    @el.on "click", ".multi_share .top", (e) =>
      $(e.currentTarget).closest(".multi_share").toggleClass "open"

    @el.on "click", ".multi_share a", (e) =>
      link = $ e.currentTarget

      w = 600
      h = 500

      win = $(window)
      win_x = window.screenLeft ? window.screenX
      win_y = window.screenTop ? window.screenY

      left = win_x + (win.width() - w) / 2
      top = win_y + (win.height() - h) / 2

      popup = window.open(link.attr("href"), 'Share', 'width='+w+',height='+h+',top=' + top + ',left=' + left)

      if popup
        popup.focus() if window.focus
        e.preventDefault()

  update_share_links: (jam) ->
    msg = jam.share_message()
    url = jam.data.url

    @el.find(".twitter_share").attr "href", "http://twitter.com/share?" + $.param {
      url: url
      text: msg
    }

    @el.find(".facebook_share").attr "href", "http://www.facebook.com/sharer.php?" + $.param {
      s: "100"
      "p[title]": jam.name
      "p[summary]": msg
      "p[url]": url
    }

    @el.find(".google_plus_share").attr "href", "https://plusone.google.com/_/+1/confirm?" + $.param {
      hl: "en"
      url: url
    }

class J.SingleJam
  constructor: (el="body") ->
    @el = $ el
    @jam = new J.Jam @el.find(".jam_box").data("jam")
    @el.find(".progress_outer").replaceWith @jam.render_time_data()
    J.Header.instance.update_share_links @jam
