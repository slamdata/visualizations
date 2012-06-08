requirejs.config({
    paths: {
          "ui"     : "libs/jquery/ui"
        , "util"   : "app/util"
        , "jlib"   : "libs/jquery"
        , "config" : "app/config"
        , "editor" : "libs/editor"
        , "ace"    : "libs/editor/ace"
    }
});

require([
      "app/util/config"
    , "app/layout"
    , "app/editors"
    , "app/bar-main"
    , "app/bar-editor"
    , "app/bar-status"
    , "app/theme"
    , "editor/editor.ace"
    , "app/editorsync"
    , "app/output"
    , "util/precog"
],

function(config, createLayout, editors, buildBarMain, buildBarEditor, buildBarStatus, theme, buildEditor, sync, buildOutput, precog) {
    precog.cache.disable();

    var layout = createLayout(config.get("ioPanesVertical"));

    buildBarMain(layout.getBarMain());
    buildBarEditor(layout.getBarEditor());

    $(theme).on("changed", function() {
        // refreshes the panes layout after theme changing
        layout.refresh();
    });

    $(theme).on("change", function(e, name) {
        config.set("theme", name);
    });

    var editor = buildEditor(layout.getCodeEditor(), config.get("ioPanesVertical"));

    editor.setTabSize(config.get("tabSize"));
    editor.setUseSoftTabs(config.get("softTabs"));

    $(layout).on("resizeCodeEditor", function() {
        editor.resize();
    });

    $(layout).on("ioOrientationChanged", function(_, vertical) {
        config.set("ioPanesVertical", vertical);
        editor.orientButton(vertical);
    });

    $(theme).on("change", function(e, name) {
        editor.setTheme(theme.getEditorTheme(name, editor.engine()));
    });

    $(editor).on("useSoftTabsChanged", function(_, value) {
//console.log("useSoftTabsChanged " + value);
        config.set("softTabs", value);
    });

    $(editor).on("tabSizeChanged", function(_, value) {
//console.log("tabSizeChanged " + value);
        config.set("tabSize", value);
    });

    var status = buildBarStatus(layout.getStatusBar(), editor, layout);

    var output = buildOutput(layout.getOutput(), editors); // TODO editors should not be passed here

    $(layout).on("resizeCodeEditor", function() {
        output.resize();
    });

    $(output).on("typeChanged", function(_, type) {
        editors.setOutputType(type);
    });

    $(precog).on("execute", function(_, data, lastExecution) {
        status.startRequest();
    });

    $(precog).on("completed", function(_, data) {
        status.endRequest(true);
        output.set(data);
        editors.setOutputResult(data);
    });
    $(precog).on("failed", function(_, data) {
        status.endRequest(false);
        output.set(data, "error");
        editors.setOutputResult(data);
    });
    $(editor).on("execute", function(_, code) {
        precog.query(code);
    });

    sync(editor, editors, config);

    $(editors).on("activated", function(_, index) {
        var result  = editors.getOutputResult(),
            type    = editors.getOutputType(),
            options = editors.getOutputOptions();
//console.log("LOADED OPTIONS " + JSON.stringify(options));
        output.set(result, type, options);
    });

    editors.load();
    if(!editors.count()) editors.add();
    editors.activate(0);

    $(output).on("optionsChanged", function(_, options) {
//console.log("SAVING OPTIONS " + JSON.stringify(options));
        editors.setOutputOptions(options);
    });

    theme.set(config.get("theme", "default"));

    config.monitor.bind("theme", function(e, name) {
        theme.set(name);
    });

    config.monitor.bind("softTabs", function(_, value) {
//console.log("from config softTabs " + value);
        editor.setUseSoftTabs(value);
    });

    config.monitor.bind("tabSize", function(_, value) {
//console.log("from config tabSize " + value);
        editor.setTabSize(value);
    });
});