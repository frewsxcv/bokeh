
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
      @model.on('change', @render, @)
      @model.on('change:columns', @update_rendering, @)


    _activated: (e) ->

      new_cols = []
      for c in  @mget_obj('data_source').get('columns')
        new_cols.push({colName:c, rendered:false, colDisplayName:c})
      @mset('columns', new_cols)
      @render()

    events:
      "click input.column_check": "update_selected_columns"

    eventGeneratorClass: ButtonEventGenerator
    evgen_options: { buttonText:"Refresh Attributes " }
    toolType: "RemoteDataSelectTool"
    tool_events: {
       activated: "_activated"
    }


    render: ->
      @template_context = _.template(@template)
      @$el.html(@template_context(@model.toJSON()));
      return this;

    template: """
      <div class='column_select'>
        <h3><%= title %> </h3>
        <ul class='column_items'>
          <% _.each(columns, function(column_data){ %>
            <li class='column_item' > 
              <input  class='column_check' 
                      name='<%= column_data.colName %>' 
                      <%= (! column_data.rendered || 'checked') %> 
                      type='checkbox' />
              <label> <%= column_data.colDisplayName %> </label>
            </li>
          <% }) %>
        </div>
      """
    update_rendering: (model, new_columns, options) ->
      old_columns = model.previous('columns')
      new_colNames = _.pluck(new_columns, 'colName')
      old_colNames = _.pluck(old_columns, 'colName')
      removed = _.difference(old_colNames, new_colNames)

      for r in removed
        @unrender_column(r)

      for col in new_columns
        if !(_.findWhere(old_columns, col))
          colName = col.colName          
          if col.rendered
            gspecs =  @model.get('glyph_specs')
            gspec_pointer = @model.get('glyph_spec_pointer')
            @inc_glyph_spec_pointer()
            if col.gspec?
              base_gspec = col.gspec
            else
              gspecs =  @model.get('glyph_specs')
              gspec_pointer = @model.get('glyph_spec_pointer')
              base_gspec = gspecs[gspec_pointer]
            @_add_renderer(colName, base_gspec)
          
          else
            @unrender_column(colName)
      @render()

    update_selected_columns: (e) ->
      rname =  $(e.currentTarget).attr('name')
      add = $(e.currentTarget).is(":checked")
      old_columns = @model.get('columns')
      # we need to copy this otherwise previous won't make any sense
      new_columns = _.map(old_columns, (c) -> return _.extend({}, c))
      modified_column = _.findWhere(new_columns, {colName:rname})
      if add
        modified_column.rendered = true
      else    
        modified_column.rendered = false
      @model.set('columns', new_columns)

    unrender_column: (rname) ->
      rmap = @model.get('renderer_map')
      renderers = rmap[rname]
      delete rmap[rname]
      @_reset_legends()
      if renderers?
        for r in renderers
          @unrender_(r)

    _add_renderer: (renderer_name, base_glyph_specs) ->
      Plotting = require("common/plotting")
      pview = @plot_view
      pmodel = @plot_view.model
      data_source = @model.get_obj('data_source')
      x_range = pmodel.get_obj("x_range")
      y_range = pmodel.get_obj("y_range")

      
      
      data_source.remote_add_column(renderer_name, =>
        data = data_source.get('data')

        scatter3 = _.extend({}, _.clone(base_glyph_specs),  {'x':'index', 'y':renderer_name,  type:'line'});
        glyphs = Plotting.create_glyphs(pmodel, scatter3, [data_source])

        pmodel.add_renderers(g.ref() for g in glyphs)


        x_min = Math.min.apply(data.index, data.index)
        x_max = Math.max.apply(data.index, data.index)
        
        y_min = Math.min.apply(data[renderer_name], data[renderer_name])
        y_max = Math.max.apply(data[renderer_name], data[renderer_name])

        y_min2 = Math.min(y_range.get('min'), y_min)
        y_max2 = Math.max(y_range.get('max'), y_max)
        if y_min2 == y_max2
          if y_min2 == 0
            [y_min2, y_max2] = [-1, 1]
          else
            [y_min2, y_max2] = [(y_min2 * .75), (y_max2 * 1.25)]
  
        if x_min == x_max
          if x_min == 0
            [x_min, x_max] = [-1, 1]
          else
            [x_min, x_max] = [(x_min * .75), (x_max * 1.25)]
  

        pview.update_range({
          xr: {start: x_min, end: x_max },
          yr: {start: y_min2, end: y_max2}})
        

        @model.get('renderer_map')[renderer_name] = glyphs
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
      if not existing_renderers?
        return
  
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
      _.each(@model.get('renderer_map'), (renderers, rname)->
        legends[rname] = (r.ref() for r in renderers));
      existing_legend.set('legends', legends)

      pview.request_render()      
            
  class RemoteDataSelectTool extends Tool.Model
    default_view: RemoteDataSelectToolView
    type: "RemoteDataSelectTool"

    defaults: () ->
      rect_base = {
        width: 5, type: 'rect', width_units: 'screen', height: 5, size:5,
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
          #_.defaults({fill_color: 'orange', line_color: 'orange'}, circle_base),
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
