
define [
  "underscore",
  "jquery",
  "backbone",
  "./tool",
  "./event_generators",
  "renderer/annotation/legend",
], (_, $, Backbone, Tool, EventGenerators, Legend) ->

  ButtonEventGenerator = EventGenerators.ButtonEventGenerator

  class RemoteDataSelectToolView extends Tool.View
    initialize: (options) ->
      @counter = 0
      @$el = @mget('control_el')
      @$el = $(@$el)
      super(options)
      @legend_count = 0
      @model.on('change', @model_change, @)

    model_change : (a,b,c) ->
      console.log('asdf')
      @render()

    events:
      "click input.column_check": "update_selected_columns"

    eventGeneratorClass: ButtonEventGenerator
    evgen_options: { buttonText:"Refresh Attributes " }
    toolType: "RemoteDataSelectTool"
    tool_events: {
       activated: "_activated"
    }

    _activated: (e) ->
      @mset('columns', @mget_obj('data_source').get('columns'))
      @render()

    render: ->
      @template_context = _.template(@template)
      console.log(@model.toJSON())
      @$el.html(@template_context(@model.toJSON()));
      return this;

    template: """
      <div class='column_select'>
        <h3><%= title %> </h3>
        <ul class='column_items'>
          <% _.each(columns, function(column_data){ %>
            <li class='column_item' > 
              <input  class='column_check' 
                      name='<%= column_data %>' 
                      <%= (!(_.has(renderer_map,column_data, true)) || 'checked') %> 
                      type='checkbox' />
              <label> <%= column_data %> </label>
            </li>
          <% }) %>
        </div>
      """

    update_selected_columns: (e) ->

    
      rname =  $(e.currentTarget).attr('name')
      add = $(e.currentTarget).is(":checked")
      if add
        gspecs =  @model.get('glyph_specs')
        gspec_pointer = @model.get('glyph_spec_pointer')
        @inc_glyph_spec_pointer()
        @_add_renderer(rname, gspecs)
        @_add_renderer(rname, _.defaults({}, gspecs, {type:'line'}))
        @_add_renderer(rname, _.defaults({}, gspecs, {type:'rects'}))
      else
        @unrender_column(rname)
      @render()


    unrender_column: (rname) ->
      rmap = @model.get('renderer_map')
      renderer = rmap[rname]
      delete rmap[rname]
      @_reset_legends()
      @unrender_(renderer)



    _add_renderer: (renderer_name, glyph_specs) ->
      Plotting = require("common/plotting")
      pview = @plot_view
      pmodel = @plot_view.model

      data_source = @model.get_obj('data_source')

      x_range = pmodel.get_obj("x_range")
      y_range = pmodel.get_obj("y_range")
      gspecs =  @model.get('glyph_specs')
      gspec_pointer = @model.get('glyph_spec_pointer')

      data_source.remote_add_column(renderer_name, =>
        data = data_source.get('data')

        scatter2 = gspecs[gspec_pointer]
        scatter2.x = 'index'
        scatter2.y = renderer_name
        glyphs = Plotting.create_glyphs(pmodel, scatter2, [data_source])
        console.log(glyphs)
        pmodel.add_renderers(g.ref() for g in glyphs)

        x_min = Math.min.apply(data.index, data.index)
        x_max = Math.max.apply(data.index, data.index)

        y_min = Math.min.apply(data[renderer_name], data[renderer_name])
        y_max = Math.max.apply(data[renderer_name], data[renderer_name])

        y_min2 = Math.min(y_range.get('min'), y_min)
        y_max2 = Math.max(y_range.get('max'), y_max)

        pview.update_range({
          xr: {start: x_min, end: x_max },
          yr: {start: y_min2, end: y_max2}})
        

        @model.get('renderer_map')[renderer_name] = glyphs[0]
        @_reset_legends()
        pview.request_render()  )

    inc_glyph_spec_pointer: () ->
      if @model.get('glyph_spec_pointer') == ((@model.get('glyph_specs').length) - 1)
        @model.set('glyph_spec_pointer', 0)
      else
        @model.set('glyph_spec_pointer', @model.get('glyph_spec_pointer') + 1)


    unrender_: (renderer) ->
      if not renderer?
        return
      pview = @plot_view
      pmodel = @plot_view.model
      existing_renderers = pmodel.get('renderers')
      modified_renderers = []
      for r in existing_renderers
        if not (r.id == renderer.id)
          modified_renderers.push(r)
      pmodel.set('renderers', modified_renderers)
      console.log(renderer.id)

    _reset_legends : () ->
      @legend_count += 1
      pview = @plot_view
      pmodel = @plot_view.model
      for r in  pmodel.get('renderers')
        if r.type == 'Legend'
          existing_legend = pmodel.resolve_ref(r)
      legends = {}
      _.each(@model.get('renderer_map'), (r, rname)->
        legends[rname] = [r.ref()];)
      existing_legend.set('legends', legends)

      pview.request_render()      
            
  class RemoteDataSelectTool extends Tool.Model
    default_view: RemoteDataSelectToolView
    type: "RemoteDataSelectTool"

    defaults: () ->
      rect_base = {
        width: 5, type: 'circle', width_units: 'screen', height: 5, size:5,
        height_units: 'screen', fill_color: 'blue', line_color: 'blue'}
      circle_base = {
        type:'line', radius:5, radius_units:'screen',
        fill_color: 'blue', line_color: 'blue'}

      return {
        columns: [],
        selected_columns: [],
        renderer_map: {},
        api_endpoint: "",
        legend_renderer : null
        glyph_specs: [
          _.defaults({fill_color: 'orange', line_color: 'orange'}, circle_base),
          _.defaults({fill_color: 'blue', line_color: 'blue'}, rect_base),
          _.defaults({fill_color: 'red', line_color: 'red'}, rect_base),
          _.defaults({fill_color: 'green', line_color: 'green'}, rect_base),
          _.defaults({fill_color: 'pink', line_color: 'pink'}, rect_base)],
        glyph_spec_pointer: 0,
        data_source: null
      }

    display_defaults: () ->
      super()

  class RemoteDataSelectTools extends Backbone.Collection
    model: RemoteDataSelectTool

  return {
    "Model": RemoteDataSelectTool,
    "Collection": new RemoteDataSelectTools(),
    "View": RemoteDataSelectToolView
  }
