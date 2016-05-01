# setup extend YAML `require` parser
require './lib/util/extend'
config = require './etc/Kodiak'
logger = require('./lib/util/logger')()
cluster = require 'cluster'

class Master

  SIG: ["SIGTERM", "SIGINT", "SIGABRT", "SIGHUP"]
  
  constructor: ->
    @exec_path = "./lib/server.coffee"
    {@cluster_core}= config
    @_cluster_closed = 0
    @_closing = no
  
  fork: ->
    master = new Master()
    master.initSignal()
    master.initCluster()
    master.spawnWorkers()
    
  initSignal: ->
    for sig in @SIG
      logger.info "[master]", "registry signal event:", sig
      process.on sig, @signalHandle sig

  signalHandle: (signal) =>
    =>
      logger.warn "[master]", "got signal:", signal
      @_closing = yes
      @stopCluster "SIGTERM"
  
  spawnWorkers: (core = @cluster_core) ->
    cluster.fork() for [1..core]

  stopCluster: (signal) ->
    worker.kill signal for _, worker of cluster.workers
    
  initCluster: ->
    cluster.setupMaster exec: @exec_path
    cluster.on 'exit', @onWorkerExit
      .on 'disconnect', @onWorkerDisconnect
      .on 'online', @onWokerOnline

  onWorkerExit: (worker, code, signal) =>
    logger.warn "[master]", """
      worker #id=#{worker.id} exit with code [#{code}], due to signal [#{signal}]
    """
    if @_closing
      @_cluster_closed++
      if @_cluster_closed is @cluster_core
        logger.warn "[master]", "all the worker process exited, master exit"
        process.exit 0
    else
      logger.info "[master]", "worker respawning..."
      @spawnWorkers 1
      
  onWorkerDisconnect: (worker) =>
    logger.warn "[master]", "worker #id=#{worker.id} disconnected"

  onWokerOnline: (worker) =>
    logger.info "[master]", "worker #id=#{worker.id} start"
