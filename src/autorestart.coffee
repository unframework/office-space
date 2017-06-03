
module.exports = (timeoutMs) ->
  setTimeout (-> window.location.reload()), timeoutMs
