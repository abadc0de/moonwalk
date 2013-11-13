--- Moonwalk configuration.

return {

  --- Your API's version number.
  ---
  --- Defaults to `'1.0'`.
  api_version = '1.0',
  
  --- Swagger version.
  ---
  --- The version of the Swagger protocol we are using. You probably don't
  --- need to change it.
  ---
  --- Defaults to `'1.2'`.
  swagger_version = '1.2',
  
  --- Whether model properties are required by default.
  ---
  --- When this is true, it can be overriden by adding `optional = true`
  --- to model property definitions.
  --- When it's false, it can be overriden by adding `required = true`.
  ---
  --- Defaults to `true`.
  model_properties_required = true,
  
  --- Use Markdown to format the "notes" section of the doc block.
  --- 
  --- Defaults to `true`.
  use_markdown = true,
  
  --- Format string for the "summary" section of a doc block.
  ---
  --- Replacement tokens: `{nickname}`, `{summary}`, `{notes}`
  summary_format = '<code>{nickname}</code><span>{summary}</span>',
  
  --- Format string for the "notes" section of a doc block.
  ---
  --- Replacement tokens: `{nickname}`, `{summary}`, `{notes}`
  notes_format = [[<div class="notes">
<h2><code>{nickname}</code><span style="color:#999"> : {summary}</span></h2>
{notes}</div>]],

}

