package controller;

class GistUploadController extends BaseController
{
	public static var GIST_REST_API = "https://api.github.com/gists/{id}";

	public function new()
	{
		super();
	}

	public function importGist(gistid : String, outputformat : String)
	{
		var gist = getGistDescription(gistid);
		if(null != gist.error)
		{
			return error(gist.error, outputformat);
		} else {
			// load files
			var html = null,
				config = null;
			for(field in Reflect.fields(gist.data.files))
			{
				var file = Reflect.field(gist.data.files, field);
				trace(file);
				switch(file.language.toLowerCase())
				{
					case 'html', 'htm':
						if(null == html)
						{
							html = loadFile(file.raw_url);
							if(null == html) return error("unable to load file in GIST: " + lastError, outputformat);
						}
					case 'json', 'ini':
						if(null == config)
						{
							config = loadFile(file.raw_url);
							if(null == config) return error("unable to load file in GIST: " + lastError, outputformat);
						}
				}
			}
			if(null == html)
				return error("The GIST doesn't inclide the required HTML file", outputformat);
			var controller = ufront.web.mvc.DependencyResolver.current.getService(controller.RenderableAPIController);
				controller.controllerContext = this.controllerContext;
			return controller.upload(html, config, outputformat);
		}
	}

	var lastError : String;
	function loadFile(url : String)
	{
		// avoid redirection, dirty trick
		url = "https://raw.github.com/gist/" + url.split("/raw/").pop();
//		https://gist.github.com/raw/1732325/d376cf433b721627e3de7d31a13ec9c996ace58b/index.html
		var http = new haxe.Http(url),
			result = null;
		http.onError = function(e) {
			lastError = e;
			result = null;
		};
		http.onData = function(s) {
			result = s;
		}
		http.request(false);
		return result;
	}

	public static function getGistDescription(id : String) : {
		?error : String,
		?data : {
			url : String,
			created_at : String,
			description: String,
//			'public': Bool,
			git_pull_url: String,
			files: Dynamic<{
				raw_url: String,
				type: String,
				content: String,
				size: Int,
				filename: String,
				language: String
			}>,
			html_url: String,
			git_push_url: String,
			history: Array<Dynamic>,
			comments: Int,
			updated_at: String,
			forks: Array<Dynamic>,
			id: String,
			user: {
			url: String,
			avatar_url: String,
			gravatar_id: String,
			login: String,
			id: Int
			}
		}
	}
	{
		var url = StringTools.replace(GIST_REST_API, "{id}", id),
			http = new haxe.Http(url),
			result = { error : null, data : null };
		http.onError = function(e) {
			result.error = e;
		};
		http.onData = function(s) {
			result.data = thx.json.Json.decode(s);
		}
		http.request(false);
		return result;
	}
}