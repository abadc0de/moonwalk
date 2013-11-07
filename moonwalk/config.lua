return {
  -- Your API's version
  api_version = '1.0',
  -- Swagger version
  swagger_version = '1.2',
  -- Path to Swagger resources.
  -- If you change this, also change it in the API explorer index.html.
  resource_listing_path = 'resources',
  -- Use Markdown to format the "notes" section of the doc block.
  use_markdown = true,
  -- Are model properties required by default?
  -- If true, override with `optional = true` in parameter definitions.
  model_properties_required = true,
  -- Format the "summary" section of a doc block.
  -- Replacement tokens: {nickname}, {summary}, {notes}
  summary_format = '<code>{nickname}</code><span>{summary}</span>',
  -- Format the "notes" section of a doc block.
  -- Replacement tokens: {nickname}, {summary}, {notes}
  notes_format = [[<div class="notes">
<h2><code>{nickname}</code><span style="color:#999"> : {summary}</span></h2>
{notes}</div>]],
}

