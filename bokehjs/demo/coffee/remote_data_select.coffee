window.render_trader_plot = (Bokeh, api_endpoint, plot_title, plot_div, selector_div,
    columns, selector_title) ->
  xs = ((x/50) for x in _.range(630))
  ys1 = (Math.sin(x) for x in xs)

  source = Bokeh.Collections('RemoteDataSource').create(
    api_endpoint: api_endpoint
    data:
      x: xs
      y1: ys1)

  xdr = Bokeh.Collections('DataRange1d').create(
    sources: [{ref: source.ref(), columns: ['x']}])

  ydr1 = Bokeh.Collections('DataRange1d').create(
    sources: [{ref: source.ref(), columns: ['y1']}])

  options = {
    dims: [700, 600], xrange: xdr, yrange: ydr1, title: plot_title
    xaxes: false, yaxes: false,
    legend:false,
    tools: false}

  
  plot1 = Bokeh.Plotting.make_plot([], source, options)
  x_axis = Bokeh.Collections('DatetimeAxis').create(
    dimension: 0
    axis_label: 'Datetime'
    location: 'bottom',
    parent: plot1.ref()
    plot: plot1.ref())
  y_axis = Bokeh.Collections('LinearAxis').create(
    dimension: 1
    axis_label: 'severity'
    location: 'min'
    parent: plot1.ref()
    plot: plot1.ref())


  plot1.add_renderers([x_axis.ref(), y_axis.ref()])
  legend_renderer = Bokeh.Legend.Collection.create({
    parent: plot1.ref()
    plot: plot1.ref()
    orientation: "top_right"
    border_line_width:0
    border_line_alpha:0
    label_text_alpha:.5
    legends: {}
  })
  plot1.add_renderers([legend_renderer.ref()])

  remote_data_select_tool = Bokeh.Collections('RemoteDataSelectTool').create(
    control_el:selector_div,
    title: selector_title,
    columns: columns, data_source:source)

  existing_tools =   plot1.get_obj('tools')
  existing_tools.push(remote_data_select_tool)
  plot1.set_obj('tools', existing_tools)
  Bokeh.Plotting.show(plot1, $(plot_div))

  console.log(remote_data_select_tool)
  return plot1, remote_data_select_tool

if require?
  require(['main'], (Bokeh) ->
    render_trader_plot(Bokeh, "http://localhost:5000/", "Trader1 metrics", "#plot_target",
      "#selector_div",
      ["trader1____largeTradeSizeWithTrendingNetExposureAgriculture.similarity",
       "trader1____AgricultureAvgTradeSizeAnomalySeverity",
       "trader1____AgricultureMaxQtyAnomalySeverity",
       "trader1____AgricultureRunningNetAnomalySeverity"],
      "Chose metrics"))
