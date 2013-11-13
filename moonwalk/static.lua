--- Static values that may exist during multiple requests.
--
--

return {

  --- API classes registered with `class`. Keyed by class name.
  api_classes = { },

  --- API overview, in the form of a resource listing. Numeric keys. 
  api_info = {},

  --- API class titles, keyed by module table
  class_titles = {},

  --- Connection classes for various host environments. Numeric keys.
  -- Should contain class modules implementing the interface described 
  -- in `connection.abstract`.
  connection_classes = {},

  --- API models, keyed by model name.
  models = {},

  --- Operation docs, keyed by operation function.
  operation_docs = {},

}

