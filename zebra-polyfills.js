(function () {
  'use strict'

  if (typeof window.globalThis === 'undefined') window.globalThis = window

  if (!Object.entries) {
    Object.entries = function (object) {
      return Object.keys(object).map(function (key) { return [key, object[key]] })
    }
  }

  if (!Object.values) {
    Object.values = function (object) {
      return Object.keys(object).map(function (key) { return object[key] })
    }
  }

  if (!Object.fromEntries) {
    Object.fromEntries = function (entries) {
      var result = {}
      Array.from(entries).forEach(function (entry) { result[entry[0]] = entry[1] })
      return result
    }
  }

  if (!Array.prototype.includes) {
    Array.prototype.includes = function (value, fromIndex) {
      return this.indexOf(value, fromIndex || 0) !== -1
    }
  }

  if (!Array.prototype.flatMap) {
    Array.prototype.flatMap = function (callback, thisArg) {
      return Array.prototype.concat.apply([], this.map(callback, thisArg))
    }
  }

  if (!String.prototype.padStart) {
    String.prototype.padStart = function (targetLength, padString) {
      var value = String(this)
      var padding = padString === undefined ? ' ' : String(padString)
      var required = Number(targetLength) - value.length
      if (required <= 0 || !padding) return value
      while (padding.length < required) padding += padding
      return padding.slice(0, required) + value
    }
  }

  if (!Promise.prototype.finally) {
    Promise.prototype.finally = function (callback) {
      var PromiseConstructor = this.constructor
      return this.then(
        function (value) {
          return PromiseConstructor.resolve(callback()).then(function () { return value })
        },
        function (reason) {
          return PromiseConstructor.resolve(callback()).then(function () { throw reason })
        }
      )
    }
  }

  if (window.crypto && !window.crypto.randomUUID) {
    window.crypto.randomUUID = function () {
      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (character) {
        var bytes = new Uint8Array(1)
        window.crypto.getRandomValues(bytes)
        var random = bytes[0] & 15
        var value = character === 'x' ? random : (random & 3) | 8
        return value.toString(16)
      })
    }
  }
})()
