# setup extend YAML `require` parser
require './util/yaml-extend'
koa = require 'koa'
{Decoder, Encoder} = require 'cbor'
koaRouter = require 'koa-router'
koaBody = require 'koa-body'
net = require 'net'
config = require '../etc/Kodiak'
logger = require('./util/logger')()

process.on 'SIGINT', ->
process.on "SIGTERM", ->
  logger.warn "[worker]", "got signal: SIGTERM"
  logger.warn "[worker]", "process exit"
  process.exit 0

serviceRouter = koaRouter()
  .prefix "#{config.api_prefix}/#{config.version}/service"
  .post "/:serviceName", ->
    req_pack =
      cmd: 'add_service'
      serviceName: @params.serviceName
      upstreams: @request.body.upstreams
      plugins: @request.body.plugins
    logger.debug "[worker]", "request packet", req_pack
    @body = yield forward req_pack
  .get '/:serviceName', ->
    req_pack =
      cmd: 'query_service'
      serviceName: @params.serviceName
    logger.debug "[worker]", "request packet", req_pack
    @body = yield forward req_pack

pluginRouter = koaRouter()
  .prefix "#{config.api_prefix}/#{config.version}/plugin"
  .post "/:pluginName/:serviceName", ->
    req_pack =
      cmd: 'config_plugin'
      serviceName: @params.serviceName
      pluginName: @params.pluginName
      cfg: @request.body.cfg
    logger.debug "[worker]", "request packet", req_pack
    @body = yield forward req_pack
  .get '/:pluginName/:serviceName', ->
    req_pack =
      cmd: 'query_plugin'
      serviceName: @params.serviceName
      pluginName: @params.pluginName
    logger.debug "[worker]", "request packet", req_pack
    @body = yield forward req_pack

forward = (req_pack) ->
  (done) ->
    socket = net.connect config.sock
    socket.on 'error', (err) ->
      done err, null  
    socket.on 'connect', ->
      ds = new Decoder()
      es = new Encoder()
      es.pipe socket
        .pipe ds
        .once 'data', (res_pack) ->
          logger.debug "[worker]", "response packet", res_pack
          done null, res_pack
      es.write req_pack

proxy = koa()
proxy.use koaBody()
proxy.use serviceRouter.routes()
proxy.use pluginRouter.routes()
proxy.listen config.port, ->
  logger.info "[worker]", 'server start listen to:', config.port