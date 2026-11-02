(() => {
  var __defProp = Object.defineProperty;
  var __defProps = Object.defineProperties;
  var __getOwnPropDescs = Object.getOwnPropertyDescriptors;
  var __getOwnPropSymbols = Object.getOwnPropertySymbols;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __propIsEnum = Object.prototype.propertyIsEnumerable;
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __spreadValues = (a, b2) => {
    for (var prop in b2 || (b2 = {}))
      if (__hasOwnProp.call(b2, prop))
        __defNormalProp(a, prop, b2[prop]);
    if (__getOwnPropSymbols)
      for (var prop of __getOwnPropSymbols(b2)) {
        if (__propIsEnum.call(b2, prop))
          __defNormalProp(a, prop, b2[prop]);
      }
    return a;
  };
  var __spreadProps = (a, b2) => __defProps(a, __getOwnPropDescs(b2));

  // vendor/supabase/supabase-js-2.118.0-es2017.bundle.mjs
  function xs(t) {
    return new Error("[unenv] ".concat(t, " is not implemented yet!"));
  }
  function He(t) {
    return Object.assign(() => {
      throw xs(t);
    }, { __unenv__: true });
  }
  var W = [];
  var D = [];
  var Ls = typeof Uint8Array > "u" ? Array : Uint8Array;
  var yt = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  for (let t = 0, e = yt.length; t < e; ++t) W[t] = yt[t], D[yt.charCodeAt(t)] = t;
  D[45] = 62;
  D[95] = 63;
  function Us(t) {
    let e = t.length;
    if (e % 4 > 0) throw new Error("Invalid string. Length must be a multiple of 4");
    let r = t.indexOf("=");
    r === -1 && (r = e);
    let s = r === e ? 0 : 4 - r % 4;
    return [r, s];
  }
  function Bs(t, e, r) {
    return (e + r) * 3 / 4 - r;
  }
  function Ds(t) {
    let e, r = Us(t), s = r[0], n = r[1], i = new Ls(Bs(t, s, n)), a = 0, o = n > 0 ? s - 4 : s, l;
    for (l = 0; l < o; l += 4) e = D[t.charCodeAt(l)] << 18 | D[t.charCodeAt(l + 1)] << 12 | D[t.charCodeAt(l + 2)] << 6 | D[t.charCodeAt(l + 3)], i[a++] = e >> 16 & 255, i[a++] = e >> 8 & 255, i[a++] = e & 255;
    return n === 2 && (e = D[t.charCodeAt(l)] << 2 | D[t.charCodeAt(l + 1)] >> 4, i[a++] = e & 255), n === 1 && (e = D[t.charCodeAt(l)] << 10 | D[t.charCodeAt(l + 1)] << 4 | D[t.charCodeAt(l + 2)] >> 2, i[a++] = e >> 8 & 255, i[a++] = e & 255), i;
  }
  function qs(t) {
    return W[t >> 18 & 63] + W[t >> 12 & 63] + W[t >> 6 & 63] + W[t & 63];
  }
  function Ms(t, e, r) {
    let s, n = [];
    for (let i = e; i < r; i += 3) s = (t[i] << 16 & 16711680) + (t[i + 1] << 8 & 65280) + (t[i + 2] & 255), n.push(qs(s));
    return n.join("");
  }
  function Kt(t) {
    let e, r = t.length, s = r % 3, n = [], i = 16383;
    for (let a = 0, o = r - s; a < o; a += i) n.push(Ms(t, a, a + i > o ? o : a + i));
    return s === 1 ? (e = t[r - 1], n.push(W[e >> 2] + W[e << 4 & 63] + "==")) : s === 2 && (e = (t[r - 2] << 8) + t[r - 1], n.push(W[e >> 10] + W[e >> 4 & 63] + W[e << 2 & 63] + "=")), n.join("");
  }
  function We(t, e, r, s, n) {
    let i, a, o = n * 8 - s - 1, l = (1 << o) - 1, u = l >> 1, h = -7, c = r ? n - 1 : 0, f = r ? -1 : 1, d = t[e + c];
    for (c += f, i = d & (1 << -h) - 1, d >>= -h, h += o; h > 0; ) i = i * 256 + t[e + c], c += f, h -= 8;
    for (a = i & (1 << -h) - 1, i >>= -h, h += s; h > 0; ) a = a * 256 + t[e + c], c += f, h -= 8;
    if (i === 0) i = 1 - u;
    else {
      if (i === l) return a ? Number.NaN : (d ? -1 : 1) * Number.POSITIVE_INFINITY;
      a = a + Math.pow(2, s), i = i - u;
    }
    return (d ? -1 : 1) * a * Math.pow(2, i - s);
  }
  function Yt(t, e, r, s, n, i) {
    let a, o, l, u = i * 8 - n - 1, h = (1 << u) - 1, c = h >> 1, f = n === 23 ? Math.pow(2, -24) - Math.pow(2, -77) : 0, d = s ? 0 : i - 1, m = s ? 1 : -1, g = e < 0 || e === 0 && 1 / e < 0 ? 1 : 0;
    for (e = Math.abs(e), Number.isNaN(e) || e === Number.POSITIVE_INFINITY ? (o = Number.isNaN(e) ? 1 : 0, a = h) : (a = Math.floor(Math.log2(e)), e * (l = Math.pow(2, -a)) < 1 && (a--, l *= 2), e += a + c >= 1 ? f / l : f * Math.pow(2, 1 - c), e * l >= 2 && (a++, l /= 2), a + c >= h ? (o = 0, a = h) : a + c >= 1 ? (o = (e * l - 1) * Math.pow(2, n), a = a + c) : (o = e * Math.pow(2, c - 1) * Math.pow(2, n), a = 0)); n >= 8; ) t[r + d] = o & 255, d += m, o /= 256, n -= 8;
    for (a = a << n | o, u += n; u > 0; ) t[r + d] = a & 255, d += m, a /= 256, u -= 8;
    t[r + d - m] |= g * 128;
  }
  var Gt = typeof Symbol == "function" && typeof Symbol.for == "function" ? Symbol.for("nodejs.util.inspect.custom") : null;
  var Fs = 50;
  var mt = 2147483647;
  p.TYPED_ARRAY_SUPPORT = Hs();
  !p.TYPED_ARRAY_SUPPORT && typeof console < "u" && typeof console.error == "function" && console.error("This environment lacks typed array (Uint8Array) support which is required by `buffer` v5.x. Use `buffer` v4.x if you require old browser support.");
  function Hs() {
    try {
      let t = new Uint8Array(1), e = { foo: function() {
        return 42;
      } };
      return Object.setPrototypeOf(e, Uint8Array.prototype), Object.setPrototypeOf(t, e), t.foo() === 42;
    } catch (t) {
      return false;
    }
  }
  Object.defineProperty(p.prototype, "parent", { enumerable: true, get: function() {
    if (p.isBuffer(this)) return this.buffer;
  } });
  Object.defineProperty(p.prototype, "offset", { enumerable: true, get: function() {
    if (p.isBuffer(this)) return this.byteOffset;
  } });
  function X(t) {
    if (t > mt) throw new RangeError('The value "' + t + '" is invalid for option "size"');
    let e = new Uint8Array(t);
    return Object.setPrototypeOf(e, p.prototype), e;
  }
  function p(t, e, r) {
    if (typeof t == "number") {
      if (typeof e == "string") throw new TypeError('The "string" argument must be of type string. Received type number');
      return vt(t);
    }
    return Xt(t, e, r);
  }
  p.poolSize = 8192;
  function Xt(t, e, r) {
    if (typeof t == "string") return Ks(t, e);
    if (ArrayBuffer.isView(t)) return Gs(t);
    if (t == null) throw new TypeError("The first argument must be one of type string, Buffer, ArrayBuffer, Array, or Array-like Object. Received type " + typeof t);
    if (K(t, ArrayBuffer) || t && K(t.buffer, ArrayBuffer) || typeof SharedArrayBuffer < "u" && (K(t, SharedArrayBuffer) || t && K(t.buffer, SharedArrayBuffer))) return Zt(t, e, r);
    if (typeof t == "number") throw new TypeError('The "value" argument must not be of type number. Received type number');
    let s = t.valueOf && t.valueOf();
    if (s != null && s !== t) return p.from(s, e, r);
    let n = Js(t);
    if (n) return n;
    if (typeof Symbol < "u" && Symbol.toPrimitive != null && typeof t[Symbol.toPrimitive] == "function") return p.from(t[Symbol.toPrimitive]("string"), e, r);
    throw new TypeError("The first argument must be one of type string, Buffer, ArrayBuffer, Array, or Array-like Object. Received type " + typeof t);
  }
  p.from = function(t, e, r) {
    return Xt(t, e, r);
  };
  Object.setPrototypeOf(p.prototype, Uint8Array.prototype);
  Object.setPrototypeOf(p, Uint8Array);
  function Qt(t) {
    if (typeof t != "number") throw new TypeError('"size" argument must be of type number');
    if (t < 0) throw new RangeError('The value "' + t + '" is invalid for option "size"');
  }
  function Ws(t, e, r) {
    return Qt(t), t <= 0 ? X(t) : e !== void 0 ? typeof r == "string" ? X(t).fill(e, r) : X(t).fill(e) : X(t);
  }
  p.alloc = function(t, e, r) {
    return Ws(t, e, r);
  };
  function vt(t) {
    return Qt(t), X(t < 0 ? 0 : _t(t) | 0);
  }
  p.allocUnsafe = function(t) {
    return vt(t);
  };
  p.allocUnsafeSlow = function(t) {
    return vt(t);
  };
  function Ks(t, e) {
    if ((typeof e != "string" || e === "") && (e = "utf8"), !p.isEncoding(e)) throw new TypeError("Unknown encoding: " + e);
    let r = er(t, e) | 0, s = X(r), n = s.write(t, e);
    return n !== r && (s = s.slice(0, n)), s;
  }
  function wt(t) {
    let e = t.length < 0 ? 0 : _t(t.length) | 0, r = X(e);
    for (let s = 0; s < e; s += 1) r[s] = t[s] & 255;
    return r;
  }
  function Gs(t) {
    if (K(t, Uint8Array)) {
      let e = new Uint8Array(t);
      return Zt(e.buffer, e.byteOffset, e.byteLength);
    }
    return wt(t);
  }
  function Zt(t, e, r) {
    if (e < 0 || t.byteLength < e) throw new RangeError('"offset" is outside of buffer bounds');
    if (t.byteLength < e + (r || 0)) throw new RangeError('"length" is outside of buffer bounds');
    let s;
    return e === void 0 && r === void 0 ? s = new Uint8Array(t) : r === void 0 ? s = new Uint8Array(t, e) : s = new Uint8Array(t, e, r), Object.setPrototypeOf(s, p.prototype), s;
  }
  function Js(t) {
    if (p.isBuffer(t)) {
      let e = _t(t.length) | 0, r = X(e);
      return r.length === 0 || t.copy(r, 0, 0, e), r;
    }
    if (t.length !== void 0) return typeof t.length != "number" || Et(t.length) ? X(0) : wt(t);
    if (t.type === "Buffer" && Array.isArray(t.data)) return wt(t.data);
  }
  function _t(t) {
    if (t >= mt) throw new RangeError("Attempt to allocate Buffer larger than maximum size: 0x" + mt.toString(16) + " bytes");
    return t | 0;
  }
  p.isBuffer = function(t) {
    return t != null && t._isBuffer === true && t !== p.prototype;
  };
  p.compare = function(t, e) {
    if (K(t, Uint8Array) && (t = p.from(t, t.offset, t.byteLength)), K(e, Uint8Array) && (e = p.from(e, e.offset, e.byteLength)), !p.isBuffer(t) || !p.isBuffer(e)) throw new TypeError('The "buf1", "buf2" arguments must be one of type Buffer or Uint8Array');
    if (t === e) return 0;
    let r = t.length, s = e.length;
    for (let n = 0, i = Math.min(r, s); n < i; ++n) if (t[n] !== e[n]) {
      r = t[n], s = e[n];
      break;
    }
    return r < s ? -1 : s < r ? 1 : 0;
  };
  p.isEncoding = function(t) {
    switch (String(t).toLowerCase()) {
      case "hex":
      case "utf8":
      case "utf-8":
      case "ascii":
      case "latin1":
      case "binary":
      case "base64":
      case "ucs2":
      case "ucs-2":
      case "utf16le":
      case "utf-16le":
        return true;
      default:
        return false;
    }
  };
  p.concat = function(t, e) {
    if (!Array.isArray(t)) throw new TypeError('"list" argument must be an Array of Buffers');
    if (t.length === 0) return p.alloc(0);
    let r;
    if (e === void 0) for (e = 0, r = 0; r < t.length; ++r) e += t[r].length;
    let s = p.allocUnsafe(e), n = 0;
    for (r = 0; r < t.length; ++r) {
      let i = t[r];
      if (K(i, Uint8Array)) n + i.length > s.length ? (p.isBuffer(i) || (i = p.from(i.buffer, i.byteOffset, i.byteLength)), i.copy(s, n)) : Uint8Array.prototype.set.call(s, i, n);
      else if (p.isBuffer(i)) i.copy(s, n);
      else throw new TypeError('"list" argument must be an Array of Buffers');
      n += i.length;
    }
    return s;
  };
  function er(t, e) {
    if (p.isBuffer(t)) return t.length;
    if (ArrayBuffer.isView(t) || K(t, ArrayBuffer)) return t.byteLength;
    if (typeof t != "string") throw new TypeError('The "string" argument must be one of type string, Buffer, or ArrayBuffer. Received type ' + typeof t);
    let r = t.length, s = arguments.length > 2 && arguments[2] === true;
    if (!s && r === 0) return 0;
    let n = false;
    for (; ; ) switch (e) {
      case "ascii":
      case "latin1":
      case "binary":
        return r;
      case "utf8":
      case "utf-8":
        return bt(t).length;
      case "ucs2":
      case "ucs-2":
      case "utf16le":
      case "utf-16le":
        return r * 2;
      case "hex":
        return r >>> 1;
      case "base64":
        return ur(t).length;
      default:
        if (n) return s ? -1 : bt(t).length;
        e = ("" + e).toLowerCase(), n = true;
    }
  }
  p.byteLength = er;
  function Vs(t, e, r) {
    let s = false;
    if ((e === void 0 || e < 0) && (e = 0), e > this.length || ((r === void 0 || r > this.length) && (r = this.length), r <= 0) || (r >>>= 0, e >>>= 0, r <= e)) return "";
    for (t || (t = "utf8"); ; ) switch (t) {
      case "hex":
        return nn(this, e, r);
      case "utf8":
      case "utf-8":
        return rr(this, e, r);
      case "ascii":
        return rn(this, e, r);
      case "latin1":
      case "binary":
        return sn(this, e, r);
      case "base64":
        return en(this, e, r);
      case "ucs2":
      case "ucs-2":
      case "utf16le":
      case "utf-16le":
        return an(this, e, r);
      default:
        if (s) throw new TypeError("Unknown encoding: " + t);
        t = (t + "").toLowerCase(), s = true;
    }
  }
  p.prototype._isBuffer = true;
  function oe(t, e, r) {
    let s = t[e];
    t[e] = t[r], t[r] = s;
  }
  p.prototype.swap16 = function() {
    let t = this.length;
    if (t % 2 !== 0) throw new RangeError("Buffer size must be a multiple of 16-bits");
    for (let e = 0; e < t; e += 2) oe(this, e, e + 1);
    return this;
  };
  p.prototype.swap32 = function() {
    let t = this.length;
    if (t % 4 !== 0) throw new RangeError("Buffer size must be a multiple of 32-bits");
    for (let e = 0; e < t; e += 4) oe(this, e, e + 3), oe(this, e + 1, e + 2);
    return this;
  };
  p.prototype.swap64 = function() {
    let t = this.length;
    if (t % 8 !== 0) throw new RangeError("Buffer size must be a multiple of 64-bits");
    for (let e = 0; e < t; e += 8) oe(this, e, e + 7), oe(this, e + 1, e + 6), oe(this, e + 2, e + 5), oe(this, e + 3, e + 4);
    return this;
  };
  p.prototype.toString = function() {
    let t = this.length;
    return t === 0 ? "" : arguments.length === 0 ? rr(this, 0, t) : Reflect.apply(Vs, this, arguments);
  };
  p.prototype.toLocaleString = p.prototype.toString;
  p.prototype.equals = function(t) {
    if (!p.isBuffer(t)) throw new TypeError("Argument must be a Buffer");
    return this === t ? true : p.compare(this, t) === 0;
  };
  p.prototype.inspect = function() {
    let t = "", e = Fs;
    return t = this.toString("hex", 0, e).replace(/(.{2})/g, "$1 ").trim(), this.length > e && (t += " ... "), "<Buffer " + t + ">";
  };
  Gt && (p.prototype[Gt] = p.prototype.inspect);
  p.prototype.compare = function(t, e, r, s, n) {
    if (K(t, Uint8Array) && (t = p.from(t, t.offset, t.byteLength)), !p.isBuffer(t)) throw new TypeError('The "target" argument must be one of type Buffer or Uint8Array. Received type ' + typeof t);
    if (e === void 0 && (e = 0), r === void 0 && (r = t ? t.length : 0), s === void 0 && (s = 0), n === void 0 && (n = this.length), e < 0 || r > t.length || s < 0 || n > this.length) throw new RangeError("out of range index");
    if (s >= n && e >= r) return 0;
    if (s >= n) return -1;
    if (e >= r) return 1;
    if (e >>>= 0, r >>>= 0, s >>>= 0, n >>>= 0, this === t) return 0;
    let i = n - s, a = r - e, o = Math.min(i, a), l = this.slice(s, n), u = t.slice(e, r);
    for (let h = 0; h < o; ++h) if (l[h] !== u[h]) {
      i = l[h], a = u[h];
      break;
    }
    return i < a ? -1 : a < i ? 1 : 0;
  };
  function tr(t, e, r, s, n) {
    if (t.length === 0) return -1;
    if (typeof r == "string" ? (s = r, r = 0) : r > 2147483647 ? r = 2147483647 : r < -2147483648 && (r = -2147483648), r = +r, Et(r) && (r = n ? 0 : t.length - 1), r < 0 && (r = t.length + r), r >= t.length) {
      if (n) return -1;
      r = t.length - 1;
    } else if (r < 0) if (n) r = 0;
    else return -1;
    if (typeof e == "string" && (e = p.from(e, s)), p.isBuffer(e)) return e.length === 0 ? -1 : Jt(t, e, r, s, n);
    if (typeof e == "number") return e = e & 255, typeof Uint8Array.prototype.indexOf == "function" ? n ? Uint8Array.prototype.indexOf.call(t, e, r) : Uint8Array.prototype.lastIndexOf.call(t, e, r) : Jt(t, [e], r, s, n);
    throw new TypeError("val must be string, number or Buffer");
  }
  function Jt(t, e, r, s, n) {
    let i = 1, a = t.length, o = e.length;
    if (s !== void 0 && (s = String(s).toLowerCase(), s === "ucs2" || s === "ucs-2" || s === "utf16le" || s === "utf-16le")) {
      if (t.length < 2 || e.length < 2) return -1;
      i = 2, a /= 2, o /= 2, r /= 2;
    }
    function l(h, c) {
      return i === 1 ? h[c] : h.readUInt16BE(c * i);
    }
    let u;
    if (n) {
      let h = -1;
      for (u = r; u < a; u++) if (l(t, u) === l(e, h === -1 ? 0 : u - h)) {
        if (h === -1 && (h = u), u - h + 1 === o) return h * i;
      } else h !== -1 && (u -= u - h), h = -1;
    } else for (r + o > a && (r = a - o), u = r; u >= 0; u--) {
      let h = true;
      for (let c = 0; c < o; c++) if (l(t, u + c) !== l(e, c)) {
        h = false;
        break;
      }
      if (h) return u;
    }
    return -1;
  }
  p.prototype.includes = function(t, e, r) {
    return this.indexOf(t, e, r) !== -1;
  };
  p.prototype.indexOf = function(t, e, r) {
    return tr(this, t, e, r, true);
  };
  p.prototype.lastIndexOf = function(t, e, r) {
    return tr(this, t, e, r, false);
  };
  function zs(t, e, r, s) {
    r = Number(r) || 0;
    let n = t.length - r;
    s ? (s = Number(s), s > n && (s = n)) : s = n;
    let i = e.length;
    s > i / 2 && (s = i / 2);
    let a;
    for (a = 0; a < s; ++a) {
      let o = Number.parseInt(e.slice(a * 2, a * 2 + 2), 16);
      if (Et(o)) return a;
      t[r + a] = o;
    }
    return a;
  }
  function Ys(t, e, r, s) {
    return Ke(bt(e, t.length - r), t, r, s);
  }
  function Xs(t, e, r, s) {
    return Ke(hn(e), t, r, s);
  }
  function Qs(t, e, r, s) {
    return Ke(ur(e), t, r, s);
  }
  function Zs(t, e, r, s) {
    return Ke(cn(e, t.length - r), t, r, s);
  }
  p.prototype.write = function(t, e, r, s) {
    if (e === void 0) s = "utf8", r = this.length, e = 0;
    else if (r === void 0 && typeof e == "string") s = e, r = this.length, e = 0;
    else if (Number.isFinite(e)) e = e >>> 0, Number.isFinite(r) ? (r = r >>> 0, s === void 0 && (s = "utf8")) : (s = r, r = void 0);
    else throw new TypeError("Buffer.write(string, encoding, offset[, length]) is no longer supported");
    let n = this.length - e;
    if ((r === void 0 || r > n) && (r = n), t.length > 0 && (r < 0 || e < 0) || e > this.length) throw new RangeError("Attempt to write outside buffer bounds");
    s || (s = "utf8");
    let i = false;
    for (; ; ) switch (s) {
      case "hex":
        return zs(this, t, e, r);
      case "utf8":
      case "utf-8":
        return Ys(this, t, e, r);
      case "ascii":
      case "latin1":
      case "binary":
        return Xs(this, t, e, r);
      case "base64":
        return Qs(this, t, e, r);
      case "ucs2":
      case "ucs-2":
      case "utf16le":
      case "utf-16le":
        return Zs(this, t, e, r);
      default:
        if (i) throw new TypeError("Unknown encoding: " + s);
        s = ("" + s).toLowerCase(), i = true;
    }
  };
  p.prototype.toJSON = function() {
    return { type: "Buffer", data: Array.prototype.slice.call(this._arr || this, 0) };
  };
  function en(t, e, r) {
    return e === 0 && r === t.length ? Kt(t) : Kt(t.slice(e, r));
  }
  function rr(t, e, r) {
    r = Math.min(t.length, r);
    let s = [], n = e;
    for (; n < r; ) {
      let i = t[n], a = null, o = i > 239 ? 4 : i > 223 ? 3 : i > 191 ? 2 : 1;
      if (n + o <= r) {
        let l, u, h, c;
        switch (o) {
          case 1:
            i < 128 && (a = i);
            break;
          case 2:
            l = t[n + 1], (l & 192) === 128 && (c = (i & 31) << 6 | l & 63, c > 127 && (a = c));
            break;
          case 3:
            l = t[n + 1], u = t[n + 2], (l & 192) === 128 && (u & 192) === 128 && (c = (i & 15) << 12 | (l & 63) << 6 | u & 63, c > 2047 && (c < 55296 || c > 57343) && (a = c));
            break;
          case 4:
            l = t[n + 1], u = t[n + 2], h = t[n + 3], (l & 192) === 128 && (u & 192) === 128 && (h & 192) === 128 && (c = (i & 15) << 18 | (l & 63) << 12 | (u & 63) << 6 | h & 63, c > 65535 && c < 1114112 && (a = c));
        }
      }
      a === null ? (a = 65533, o = 1) : a > 65535 && (a -= 65536, s.push(a >>> 10 & 1023 | 55296), a = 56320 | a & 1023), s.push(a), n += o;
    }
    return tn(s);
  }
  var Vt = 4096;
  function tn(t) {
    let e = t.length;
    if (e <= Vt) return String.fromCharCode.apply(String, t);
    let r = "", s = 0;
    for (; s < e; ) r += String.fromCharCode.apply(String, t.slice(s, s += Vt));
    return r;
  }
  function rn(t, e, r) {
    let s = "";
    r = Math.min(t.length, r);
    for (let n = e; n < r; ++n) s += String.fromCharCode(t[n] & 127);
    return s;
  }
  function sn(t, e, r) {
    let s = "";
    r = Math.min(t.length, r);
    for (let n = e; n < r; ++n) s += String.fromCharCode(t[n]);
    return s;
  }
  function nn(t, e, r) {
    let s = t.length;
    (!e || e < 0) && (e = 0), (!r || r < 0 || r > s) && (r = s);
    let n = "";
    for (let i = e; i < r; ++i) n += dn[t[i]];
    return n;
  }
  function an(t, e, r) {
    let s = t.slice(e, r), n = "";
    for (let i = 0; i < s.length - 1; i += 2) n += String.fromCharCode(s[i] + s[i + 1] * 256);
    return n;
  }
  p.prototype.slice = function(t, e) {
    let r = this.length;
    t = Math.trunc(t), e = e === void 0 ? r : Math.trunc(e), t < 0 ? (t += r, t < 0 && (t = 0)) : t > r && (t = r), e < 0 ? (e += r, e < 0 && (e = 0)) : e > r && (e = r), e < t && (e = t);
    let s = this.subarray(t, e);
    return Object.setPrototypeOf(s, p.prototype), s;
  };
  function P(t, e, r) {
    if (t % 1 !== 0 || t < 0) throw new RangeError("offset is not uint");
    if (t + e > r) throw new RangeError("Trying to access beyond buffer length");
  }
  p.prototype.readUintLE = p.prototype.readUIntLE = function(t, e, r) {
    t = t >>> 0, e = e >>> 0, r || P(t, e, this.length);
    let s = this[t], n = 1, i = 0;
    for (; ++i < e && (n *= 256); ) s += this[t + i] * n;
    return s;
  };
  p.prototype.readUintBE = p.prototype.readUIntBE = function(t, e, r) {
    t = t >>> 0, e = e >>> 0, r || P(t, e, this.length);
    let s = this[t + --e], n = 1;
    for (; e > 0 && (n *= 256); ) s += this[t + --e] * n;
    return s;
  };
  p.prototype.readUint8 = p.prototype.readUInt8 = function(t, e) {
    return t = t >>> 0, e || P(t, 1, this.length), this[t];
  };
  p.prototype.readUint16LE = p.prototype.readUInt16LE = function(t, e) {
    return t = t >>> 0, e || P(t, 2, this.length), this[t] | this[t + 1] << 8;
  };
  p.prototype.readUint16BE = p.prototype.readUInt16BE = function(t, e) {
    return t = t >>> 0, e || P(t, 2, this.length), this[t] << 8 | this[t + 1];
  };
  p.prototype.readUint32LE = p.prototype.readUInt32LE = function(t, e) {
    return t = t >>> 0, e || P(t, 4, this.length), (this[t] | this[t + 1] << 8 | this[t + 2] << 16) + this[t + 3] * 16777216;
  };
  p.prototype.readUint32BE = p.prototype.readUInt32BE = function(t, e) {
    return t = t >>> 0, e || P(t, 4, this.length), this[t] * 16777216 + (this[t + 1] << 16 | this[t + 2] << 8 | this[t + 3]);
  };
  p.prototype.readBigUInt64LE = ne(function(t) {
    t = t >>> 0, ge(t, "offset");
    let e = this[t], r = this[t + 7];
    (e === void 0 || r === void 0) && Ie(t, this.length - 8);
    let s = e + this[++t] * 2 ** 8 + this[++t] * 2 ** 16 + this[++t] * 2 ** 24, n = this[++t] + this[++t] * 2 ** 8 + this[++t] * 2 ** 16 + r * 2 ** 24;
    return BigInt(s) + (BigInt(n) << BigInt(32));
  });
  p.prototype.readBigUInt64BE = ne(function(t) {
    t = t >>> 0, ge(t, "offset");
    let e = this[t], r = this[t + 7];
    (e === void 0 || r === void 0) && Ie(t, this.length - 8);
    let s = e * 2 ** 24 + this[++t] * 2 ** 16 + this[++t] * 2 ** 8 + this[++t], n = this[++t] * 2 ** 24 + this[++t] * 2 ** 16 + this[++t] * 2 ** 8 + r;
    return (BigInt(s) << BigInt(32)) + BigInt(n);
  });
  p.prototype.readIntLE = function(t, e, r) {
    t = t >>> 0, e = e >>> 0, r || P(t, e, this.length);
    let s = this[t], n = 1, i = 0;
    for (; ++i < e && (n *= 256); ) s += this[t + i] * n;
    return n *= 128, s >= n && (s -= Math.pow(2, 8 * e)), s;
  };
  p.prototype.readIntBE = function(t, e, r) {
    t = t >>> 0, e = e >>> 0, r || P(t, e, this.length);
    let s = e, n = 1, i = this[t + --s];
    for (; s > 0 && (n *= 256); ) i += this[t + --s] * n;
    return n *= 128, i >= n && (i -= Math.pow(2, 8 * e)), i;
  };
  p.prototype.readInt8 = function(t, e) {
    return t = t >>> 0, e || P(t, 1, this.length), this[t] & 128 ? (255 - this[t] + 1) * -1 : this[t];
  };
  p.prototype.readInt16LE = function(t, e) {
    t = t >>> 0, e || P(t, 2, this.length);
    let r = this[t] | this[t + 1] << 8;
    return r & 32768 ? r | 4294901760 : r;
  };
  p.prototype.readInt16BE = function(t, e) {
    t = t >>> 0, e || P(t, 2, this.length);
    let r = this[t + 1] | this[t] << 8;
    return r & 32768 ? r | 4294901760 : r;
  };
  p.prototype.readInt32LE = function(t, e) {
    return t = t >>> 0, e || P(t, 4, this.length), this[t] | this[t + 1] << 8 | this[t + 2] << 16 | this[t + 3] << 24;
  };
  p.prototype.readInt32BE = function(t, e) {
    return t = t >>> 0, e || P(t, 4, this.length), this[t] << 24 | this[t + 1] << 16 | this[t + 2] << 8 | this[t + 3];
  };
  p.prototype.readBigInt64LE = ne(function(t) {
    t = t >>> 0, ge(t, "offset");
    let e = this[t], r = this[t + 7];
    (e === void 0 || r === void 0) && Ie(t, this.length - 8);
    let s = this[t + 4] + this[t + 5] * 2 ** 8 + this[t + 6] * 2 ** 16 + (r << 24);
    return (BigInt(s) << BigInt(32)) + BigInt(e + this[++t] * 2 ** 8 + this[++t] * 2 ** 16 + this[++t] * 2 ** 24);
  });
  p.prototype.readBigInt64BE = ne(function(t) {
    t = t >>> 0, ge(t, "offset");
    let e = this[t], r = this[t + 7];
    (e === void 0 || r === void 0) && Ie(t, this.length - 8);
    let s = (e << 24) + this[++t] * 2 ** 16 + this[++t] * 2 ** 8 + this[++t];
    return (BigInt(s) << BigInt(32)) + BigInt(this[++t] * 2 ** 24 + this[++t] * 2 ** 16 + this[++t] * 2 ** 8 + r);
  });
  p.prototype.readFloatLE = function(t, e) {
    return t = t >>> 0, e || P(t, 4, this.length), We(this, t, true, 23, 4);
  };
  p.prototype.readFloatBE = function(t, e) {
    return t = t >>> 0, e || P(t, 4, this.length), We(this, t, false, 23, 4);
  };
  p.prototype.readDoubleLE = function(t, e) {
    return t = t >>> 0, e || P(t, 8, this.length), We(this, t, true, 52, 8);
  };
  p.prototype.readDoubleBE = function(t, e) {
    return t = t >>> 0, e || P(t, 8, this.length), We(this, t, false, 52, 8);
  };
  function x(t, e, r, s, n, i) {
    if (!p.isBuffer(t)) throw new TypeError('"buffer" argument must be a Buffer instance');
    if (e > n || e < i) throw new RangeError('"value" argument is out of bounds');
    if (r + s > t.length) throw new RangeError("Index out of range");
  }
  p.prototype.writeUintLE = p.prototype.writeUIntLE = function(t, e, r, s) {
    if (t = +t, e = e >>> 0, r = r >>> 0, !s) {
      let a = Math.pow(2, 8 * r) - 1;
      x(this, t, e, r, a, 0);
    }
    let n = 1, i = 0;
    for (this[e] = t & 255; ++i < r && (n *= 256); ) this[e + i] = t / n & 255;
    return e + r;
  };
  p.prototype.writeUintBE = p.prototype.writeUIntBE = function(t, e, r, s) {
    if (t = +t, e = e >>> 0, r = r >>> 0, !s) {
      let a = Math.pow(2, 8 * r) - 1;
      x(this, t, e, r, a, 0);
    }
    let n = r - 1, i = 1;
    for (this[e + n] = t & 255; --n >= 0 && (i *= 256); ) this[e + n] = t / i & 255;
    return e + r;
  };
  p.prototype.writeUint8 = p.prototype.writeUInt8 = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 1, 255, 0), this[e] = t & 255, e + 1;
  };
  p.prototype.writeUint16LE = p.prototype.writeUInt16LE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 2, 65535, 0), this[e] = t & 255, this[e + 1] = t >>> 8, e + 2;
  };
  p.prototype.writeUint16BE = p.prototype.writeUInt16BE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 2, 65535, 0), this[e] = t >>> 8, this[e + 1] = t & 255, e + 2;
  };
  p.prototype.writeUint32LE = p.prototype.writeUInt32LE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 4, 4294967295, 0), this[e + 3] = t >>> 24, this[e + 2] = t >>> 16, this[e + 1] = t >>> 8, this[e] = t & 255, e + 4;
  };
  p.prototype.writeUint32BE = p.prototype.writeUInt32BE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 4, 4294967295, 0), this[e] = t >>> 24, this[e + 1] = t >>> 16, this[e + 2] = t >>> 8, this[e + 3] = t & 255, e + 4;
  };
  function sr(t, e, r, s, n) {
    lr(e, s, n, t, r, 7);
    let i = Number(e & BigInt(4294967295));
    t[r++] = i, i = i >> 8, t[r++] = i, i = i >> 8, t[r++] = i, i = i >> 8, t[r++] = i;
    let a = Number(e >> BigInt(32) & BigInt(4294967295));
    return t[r++] = a, a = a >> 8, t[r++] = a, a = a >> 8, t[r++] = a, a = a >> 8, t[r++] = a, r;
  }
  function nr(t, e, r, s, n) {
    lr(e, s, n, t, r, 7);
    let i = Number(e & BigInt(4294967295));
    t[r + 7] = i, i = i >> 8, t[r + 6] = i, i = i >> 8, t[r + 5] = i, i = i >> 8, t[r + 4] = i;
    let a = Number(e >> BigInt(32) & BigInt(4294967295));
    return t[r + 3] = a, a = a >> 8, t[r + 2] = a, a = a >> 8, t[r + 1] = a, a = a >> 8, t[r] = a, r + 8;
  }
  p.prototype.writeBigUInt64LE = ne(function(t, e = 0) {
    return sr(this, t, e, BigInt(0), BigInt("0xffffffffffffffff"));
  });
  p.prototype.writeBigUInt64BE = ne(function(t, e = 0) {
    return nr(this, t, e, BigInt(0), BigInt("0xffffffffffffffff"));
  });
  p.prototype.writeIntLE = function(t, e, r, s) {
    if (t = +t, e = e >>> 0, !s) {
      let o = Math.pow(2, 8 * r - 1);
      x(this, t, e, r, o - 1, -o);
    }
    let n = 0, i = 1, a = 0;
    for (this[e] = t & 255; ++n < r && (i *= 256); ) t < 0 && a === 0 && this[e + n - 1] !== 0 && (a = 1), this[e + n] = Math.trunc(t / i) - a & 255;
    return e + r;
  };
  p.prototype.writeIntBE = function(t, e, r, s) {
    if (t = +t, e = e >>> 0, !s) {
      let o = Math.pow(2, 8 * r - 1);
      x(this, t, e, r, o - 1, -o);
    }
    let n = r - 1, i = 1, a = 0;
    for (this[e + n] = t & 255; --n >= 0 && (i *= 256); ) t < 0 && a === 0 && this[e + n + 1] !== 0 && (a = 1), this[e + n] = Math.trunc(t / i) - a & 255;
    return e + r;
  };
  p.prototype.writeInt8 = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 1, 127, -128), t < 0 && (t = 255 + t + 1), this[e] = t & 255, e + 1;
  };
  p.prototype.writeInt16LE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 2, 32767, -32768), this[e] = t & 255, this[e + 1] = t >>> 8, e + 2;
  };
  p.prototype.writeInt16BE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 2, 32767, -32768), this[e] = t >>> 8, this[e + 1] = t & 255, e + 2;
  };
  p.prototype.writeInt32LE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 4, 2147483647, -2147483648), this[e] = t & 255, this[e + 1] = t >>> 8, this[e + 2] = t >>> 16, this[e + 3] = t >>> 24, e + 4;
  };
  p.prototype.writeInt32BE = function(t, e, r) {
    return t = +t, e = e >>> 0, r || x(this, t, e, 4, 2147483647, -2147483648), t < 0 && (t = 4294967295 + t + 1), this[e] = t >>> 24, this[e + 1] = t >>> 16, this[e + 2] = t >>> 8, this[e + 3] = t & 255, e + 4;
  };
  p.prototype.writeBigInt64LE = ne(function(t, e = 0) {
    return sr(this, t, e, -BigInt("0x8000000000000000"), BigInt("0x7fffffffffffffff"));
  });
  p.prototype.writeBigInt64BE = ne(function(t, e = 0) {
    return nr(this, t, e, -BigInt("0x8000000000000000"), BigInt("0x7fffffffffffffff"));
  });
  function ir(t, e, r, s, n, i) {
    if (r + s > t.length) throw new RangeError("Index out of range");
    if (r < 0) throw new RangeError("Index out of range");
  }
  function ar(t, e, r, s, n) {
    return e = +e, r = r >>> 0, n || ir(t, e, r, 4, 34028234663852886e22, -34028234663852886e22), Yt(t, e, r, s, 23, 4), r + 4;
  }
  p.prototype.writeFloatLE = function(t, e, r) {
    return ar(this, t, e, true, r);
  };
  p.prototype.writeFloatBE = function(t, e, r) {
    return ar(this, t, e, false, r);
  };
  function or(t, e, r, s, n) {
    return e = +e, r = r >>> 0, n || ir(t, e, r, 8, 17976931348623157e292, -17976931348623157e292), Yt(t, e, r, s, 52, 8), r + 8;
  }
  p.prototype.writeDoubleLE = function(t, e, r) {
    return or(this, t, e, true, r);
  };
  p.prototype.writeDoubleBE = function(t, e, r) {
    return or(this, t, e, false, r);
  };
  p.prototype.copy = function(t, e, r, s) {
    if (!p.isBuffer(t)) throw new TypeError("argument should be a Buffer");
    if (r || (r = 0), !s && s !== 0 && (s = this.length), e >= t.length && (e = t.length), e || (e = 0), s > 0 && s < r && (s = r), s === r || t.length === 0 || this.length === 0) return 0;
    if (e < 0) throw new RangeError("targetStart out of bounds");
    if (r < 0 || r >= this.length) throw new RangeError("Index out of range");
    if (s < 0) throw new RangeError("sourceEnd out of bounds");
    s > this.length && (s = this.length), t.length - e < s - r && (s = t.length - e + r);
    let n = s - r;
    return this === t && typeof Uint8Array.prototype.copyWithin == "function" ? this.copyWithin(e, r, s) : Uint8Array.prototype.set.call(t, this.subarray(r, s), e), n;
  };
  p.prototype.fill = function(t, e, r, s) {
    if (typeof t == "string") {
      if (typeof e == "string" ? (s = e, e = 0, r = this.length) : typeof r == "string" && (s = r, r = this.length), s !== void 0 && typeof s != "string") throw new TypeError("encoding must be a string");
      if (typeof s == "string" && !p.isEncoding(s)) throw new TypeError("Unknown encoding: " + s);
      if (t.length === 1) {
        let i = t.charCodeAt(0);
        (s === "utf8" && i < 128 || s === "latin1") && (t = i);
      }
    } else typeof t == "number" ? t = t & 255 : typeof t == "boolean" && (t = Number(t));
    if (e < 0 || this.length < e || this.length < r) throw new RangeError("Out of range index");
    if (r <= e) return this;
    e = e >>> 0, r = r === void 0 ? this.length : r >>> 0, t || (t = 0);
    let n;
    if (typeof t == "number") for (n = e; n < r; ++n) this[n] = t;
    else {
      let i = p.isBuffer(t) ? t : p.from(t, s), a = i.length;
      if (a === 0) throw new TypeError('The value "' + t + '" is invalid for argument "value"');
      for (n = 0; n < r - e; ++n) this[n + e] = i[n % a];
    }
    return this;
  };
  var pe = {};
  function kt(t, e, r) {
    pe[t] = class extends r {
      constructor() {
        super(), Object.defineProperty(this, "message", { value: Reflect.apply(e, this, arguments), writable: true, configurable: true }), this.name = "".concat(this.name, " [").concat(t, "]"), this.stack, delete this.name;
      }
      get code() {
        return t;
      }
      set code(s) {
        Object.defineProperty(this, "code", { configurable: true, enumerable: true, value: s, writable: true });
      }
      toString() {
        return "".concat(this.name, " [").concat(t, "]: ").concat(this.message);
      }
    };
  }
  kt("ERR_BUFFER_OUT_OF_BOUNDS", function(t) {
    return t ? "".concat(t, " is outside of buffer bounds") : "Attempt to access memory outside buffer bounds";
  }, RangeError);
  kt("ERR_INVALID_ARG_TYPE", function(t, e) {
    return 'The "'.concat(t, '" argument must be of type number. Received type ').concat(typeof e);
  }, TypeError);
  kt("ERR_OUT_OF_RANGE", function(t, e, r) {
    let s = 'The value of "'.concat(t, '" is out of range.'), n = r;
    return Number.isInteger(r) && Math.abs(r) > 2 ** 32 ? n = zt(String(r)) : typeof r == "bigint" && (n = String(r), (r > BigInt(2) ** BigInt(32) || r < -(BigInt(2) ** BigInt(32))) && (n = zt(n)), n += "n"), s += " It must be ".concat(e, ". Received ").concat(n), s;
  }, RangeError);
  function zt(t) {
    let e = "", r = t.length, s = t[0] === "-" ? 1 : 0;
    for (; r >= s + 4; r -= 3) e = "_".concat(t.slice(r - 3, r)).concat(e);
    return "".concat(t.slice(0, r)).concat(e);
  }
  function on(t, e, r) {
    ge(e, "offset"), (t[e] === void 0 || t[e + r] === void 0) && Ie(e, t.length - (r + 1));
  }
  function lr(t, e, r, s, n, i) {
    if (t > r || t < e) {
      let a = typeof e == "bigint" ? "n" : "", o;
      throw i > 3 ? o = e === 0 || e === BigInt(0) ? ">= 0".concat(a, " and < 2").concat(a, " ** ").concat((i + 1) * 8).concat(a) : ">= -(2".concat(a, " ** ").concat((i + 1) * 8 - 1).concat(a, ") and < 2 ** ").concat((i + 1) * 8 - 1).concat(a) : o = ">= ".concat(e).concat(a, " and <= ").concat(r).concat(a), new pe.ERR_OUT_OF_RANGE("value", o, t);
    }
    on(s, n, i);
  }
  function ge(t, e) {
    if (typeof t != "number") throw new pe.ERR_INVALID_ARG_TYPE(e, "number", t);
  }
  function Ie(t, e, r) {
    throw Math.floor(t) !== t ? (ge(t, r), new pe.ERR_OUT_OF_RANGE(r || "offset", "an integer", t)) : e < 0 ? new pe.ERR_BUFFER_OUT_OF_BOUNDS() : new pe.ERR_OUT_OF_RANGE(r || "offset", ">= ".concat(r ? 1 : 0, " and <= ").concat(e), t);
  }
  var ln = /[^\w+/-]/g;
  function un(t) {
    if (t = t.split("=")[0], t = t.trim().replace(ln, ""), t.length < 2) return "";
    for (; t.length % 4 !== 0; ) t = t + "=";
    return t;
  }
  function bt(t, e) {
    e = e || Number.POSITIVE_INFINITY;
    let r, s = t.length, n = null, i = [];
    for (let a = 0; a < s; ++a) {
      if (r = t.charCodeAt(a), r > 55295 && r < 57344) {
        if (!n) {
          if (r > 56319) {
            (e -= 3) > -1 && i.push(239, 191, 189);
            continue;
          } else if (a + 1 === s) {
            (e -= 3) > -1 && i.push(239, 191, 189);
            continue;
          }
          n = r;
          continue;
        }
        if (r < 56320) {
          (e -= 3) > -1 && i.push(239, 191, 189), n = r;
          continue;
        }
        r = (n - 55296 << 10 | r - 56320) + 65536;
      } else n && (e -= 3) > -1 && i.push(239, 191, 189);
      if (n = null, r < 128) {
        if ((e -= 1) < 0) break;
        i.push(r);
      } else if (r < 2048) {
        if ((e -= 2) < 0) break;
        i.push(r >> 6 | 192, r & 63 | 128);
      } else if (r < 65536) {
        if ((e -= 3) < 0) break;
        i.push(r >> 12 | 224, r >> 6 & 63 | 128, r & 63 | 128);
      } else if (r < 1114112) {
        if ((e -= 4) < 0) break;
        i.push(r >> 18 | 240, r >> 12 & 63 | 128, r >> 6 & 63 | 128, r & 63 | 128);
      } else throw new Error("Invalid code point");
    }
    return i;
  }
  function hn(t) {
    let e = [];
    for (let r = 0; r < t.length; ++r) e.push(t.charCodeAt(r) & 255);
    return e;
  }
  function cn(t, e) {
    let r, s, n, i = [];
    for (let a = 0; a < t.length && !((e -= 2) < 0); ++a) r = t.charCodeAt(a), s = r >> 8, n = r % 256, i.push(n, s);
    return i;
  }
  function ur(t) {
    return Ds(un(t));
  }
  function Ke(t, e, r, s) {
    let n;
    for (n = 0; n < s && !(n + r >= e.length || n >= t.length); ++n) e[n + r] = t[n];
    return n;
  }
  function K(t, e) {
    return t instanceof e || t != null && t.constructor != null && t.constructor.name != null && t.constructor.name === e.name;
  }
  function Et(t) {
    return t !== t;
  }
  var dn = (function() {
    let t = "0123456789abcdef", e = Array.from({ length: 256 });
    for (let r = 0; r < 16; ++r) {
      let s = r * 16;
      for (let n = 0; n < 16; ++n) e[s + n] = t[r] + t[n];
    }
    return e;
  })();
  function ne(t) {
    return typeof BigInt > "u" ? fn : t;
  }
  function fn() {
    throw new Error("BigInt not supported");
  }
  var St = globalThis.Buffer || p;
  var xo = globalThis.Blob;
  var Lo = He("buffer.resolveObjectURL");
  var Uo = He("buffer.transcode");
  var Bo = He("buffer.isUtf8");
  var Do = He("buffer.isAscii");
  var qo = globalThis.btoa.bind(globalThis);
  var Mo = globalThis.atob.bind(globalThis);
  var pn = Object.defineProperty;
  var hr = Object.getOwnPropertySymbols;
  var gn = Object.prototype.hasOwnProperty;
  var yn = Object.prototype.propertyIsEnumerable;
  var cr = (t, e, r) => e in t ? pn(t, e, { enumerable: true, configurable: true, writable: true, value: r }) : t[e] = r;
  var Tt = (t, e) => {
    for (var r in e || (e = {})) gn.call(e, r) && cr(t, r, e[r]);
    if (hr) for (var r of hr(e)) yn.call(e, r) && cr(t, r, e[r]);
    return t;
  };
  var mn = Symbol.for("@supabase/supabase-js.traceContextExtractor");
  function wn() {
    return globalThis[mn];
  }
  function ft(t, e) {
    var r = {};
    for (var s in t) Object.prototype.hasOwnProperty.call(t, s) && e.indexOf(s) < 0 && (r[s] = t[s]);
    if (t != null && typeof Object.getOwnPropertySymbols == "function") for (var n = 0, s = Object.getOwnPropertySymbols(t); n < s.length; n++) e.indexOf(s[n]) < 0 && Object.prototype.propertyIsEnumerable.call(t, s[n]) && (r[s[n]] = t[s[n]]);
    return r;
  }
  function bn(t, e, r, s) {
    function n(i) {
      return i instanceof r ? i : new r(function(a) {
        a(i);
      });
    }
    return new (r || (r = Promise))(function(i, a) {
      function o(h) {
        try {
          u(s.next(h));
        } catch (c) {
          a(c);
        }
      }
      function l(h) {
        try {
          u(s.throw(h));
        } catch (c) {
          a(c);
        }
      }
      function u(h) {
        h.done ? i(h.value) : n(h.value).then(o, l);
      }
      u((s = s.apply(t, e || [])).next());
    });
  }
  var vn = (t) => t ? (...e) => t(...e) : (...e) => fetch(...e);
  var Ht = class extends Error {
    constructor(t, e = "FunctionsError", r) {
      super(t), this.name = e, this.context = r;
    }
    toJSON() {
      return { name: this.name, message: this.message, context: this.context };
    }
  };
  var _n = class extends Ht {
    constructor(t) {
      super("Failed to send a request to the Edge Function", "FunctionsFetchError", t);
    }
  };
  var dr = class extends Ht {
    constructor(t) {
      super("Relay Error invoking the Edge Function", "FunctionsRelayError", t);
    }
  };
  var fr = class extends Ht {
    constructor(t) {
      super("Edge Function returned a non-2xx status code", "FunctionsHttpError", t);
    }
  };
  var Ct;
  (function(t) {
    t.Any = "any", t.ApNortheast1 = "ap-northeast-1", t.ApNortheast2 = "ap-northeast-2", t.ApSouth1 = "ap-south-1", t.ApSoutheast1 = "ap-southeast-1", t.ApSoutheast2 = "ap-southeast-2", t.CaCentral1 = "ca-central-1", t.EuCentral1 = "eu-central-1", t.EuWest1 = "eu-west-1", t.EuWest2 = "eu-west-2", t.EuWest3 = "eu-west-3", t.SaEast1 = "sa-east-1", t.UsEast1 = "us-east-1", t.UsWest1 = "us-west-1", t.UsWest2 = "us-west-2";
  })(Ct || (Ct = {}));
  var kn = class {
    constructor(t, { headers: e = {}, customFetch: r, region: s = Ct.Any } = {}) {
      this.url = t, this.headers = e, this.region = s, this.fetch = vn(r);
    }
    setAuth(t) {
      this.headers.Authorization = "Bearer ".concat(t);
    }
    invoke(t) {
      return bn(this, arguments, void 0, function* (e, r = {}) {
        var s, n;
        let i, a, o;
        try {
          let { headers: l, method: u, body: h, signal: c, timeout: f } = r, d = {}, { region: m } = r;
          m || (m = this.region);
          let g = new URL("".concat(this.url, "/").concat(e));
          m && m !== "any" && (d["x-region"] = m, g.searchParams.set("forceFunctionRegion", m));
          let y, E = !!l && Object.keys(l).some((O) => O.toLowerCase() === "content-type");
          h && !E ? typeof Blob != "undefined" && h instanceof Blob || h instanceof ArrayBuffer ? (d["Content-Type"] = h.type || "application/octet-stream", y = h) : typeof h == "string" ? (d["Content-Type"] = "text/plain", y = h) : typeof FormData != "undefined" && h instanceof FormData ? y = h : (d["Content-Type"] = "application/json", y = JSON.stringify(h)) : h && typeof h != "string" && !(typeof Blob != "undefined" && h instanceof Blob) && !(h instanceof ArrayBuffer) && !(typeof FormData != "undefined" && h instanceof FormData) ? y = JSON.stringify(h) : y = h;
          let k = c;
          f && (a = new AbortController(), i = setTimeout(() => a.abort(), f), c ? (k = a.signal, o = () => a.abort(), c.addEventListener("abort", o)) : k = a.signal);
          let _ = yield this.fetch(g.toString(), { method: u || "POST", headers: Object.assign(Object.assign(Object.assign({}, d), this.headers), l), body: y, signal: k }).catch((O) => {
            throw new _n(O);
          }), R = _.headers.get("x-relay-error");
          if (R && R === "true") throw new dr(_);
          if (!_.ok) throw new fr(_);
          let j = ((s = _.headers.get("Content-Type")) !== null && s !== void 0 ? s : "text/plain").split(";")[0].trim().toLowerCase(), S;
          return j === "application/json" ? S = yield _.json() : j === "application/octet-stream" || j === "application/pdf" ? S = yield _.blob() : j === "text/event-stream" ? S = _ : j === "multipart/form-data" ? S = yield _.formData() : S = yield _.text(), { data: S, error: null, response: _ };
        } catch (l) {
          return { data: null, error: l, response: l instanceof fr || l instanceof dr ? l.context : void 0 };
        } finally {
          i && clearTimeout(i), o && ((n = r.signal) === null || n === void 0 || n.removeEventListener("abort", o));
        }
      });
    }
  };
  var ke = class extends Error {
    constructor(t) {
      super(t.message), this.name = "PostgrestError", this.details = t.details, this.hint = t.hint, this.code = t.code;
    }
    toJSON() {
      return { name: this.name, message: this.message, details: this.details, hint: this.hint, code: this.code };
    }
  };
  var ss = 3;
  var pr = (t) => Math.min(1e3 * 2 ** t, 3e4);
  var En = [520, 503];
  var ns = ["GET", "HEAD", "OPTIONS"];
  function xe(t) {
    "@babel/helpers - typeof";
    return xe = typeof Symbol == "function" && typeof Symbol.iterator == "symbol" ? function(e) {
      return typeof e;
    } : function(e) {
      return e && typeof Symbol == "function" && e.constructor === Symbol && e !== Symbol.prototype ? "symbol" : typeof e;
    }, xe(t);
  }
  function Sn(t, e) {
    if (xe(t) != "object" || !t) return t;
    var r = t[Symbol.toPrimitive];
    if (r !== void 0) {
      var s = r.call(t, e || "default");
      if (xe(s) != "object") return s;
      throw new TypeError("@@toPrimitive must return a primitive value.");
    }
    return (e === "string" ? String : Number)(t);
  }
  function Tn(t) {
    var e = Sn(t, "string");
    return xe(e) == "symbol" ? e : e + "";
  }
  function Rn(t, e, r) {
    return (e = Tn(e)) in t ? Object.defineProperty(t, e, { value: r, enumerable: true, configurable: true, writable: true }) : t[e] = r, t;
  }
  function gr(t, e) {
    var r = Object.keys(t);
    if (Object.getOwnPropertySymbols) {
      var s = Object.getOwnPropertySymbols(t);
      e && (s = s.filter(function(n) {
        return Object.getOwnPropertyDescriptor(t, n).enumerable;
      })), r.push.apply(r, s);
    }
    return r;
  }
  function ce(t) {
    for (var e = 1; e < arguments.length; e++) {
      var r = arguments[e] != null ? arguments[e] : {};
      e % 2 ? gr(Object(r), true).forEach(function(s) {
        Rn(t, s, r[s]);
      }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(t, Object.getOwnPropertyDescriptors(r)) : gr(Object(r)).forEach(function(s) {
        Object.defineProperty(t, s, Object.getOwnPropertyDescriptor(r, s));
      });
    }
    return t;
  }
  function yr(t, e) {
    return new Promise((r) => {
      if (e != null && e.aborted) {
        r();
        return;
      }
      let s = setTimeout(() => {
        e == null || e.removeEventListener("abort", n), r();
      }, t);
      function n() {
        clearTimeout(s), r();
      }
      e == null || e.addEventListener("abort", n);
    });
  }
  function An(t, e, r, s) {
    return !(!s || r >= ss || !ns.includes(t) || !En.includes(e));
  }
  async function is(t, e, r, s) {
    let n = 0;
    for (; ; ) {
      let l = ce({}, r.headers);
      n > 0 && (l["X-Retry-Count"] = String(n));
      let u;
      try {
        u = await t(e, { method: r.method, headers: l, body: r.body, signal: r.signal });
      } catch (h) {
        var i;
        if ((h == null ? void 0 : h.name) === "AbortError" || (h == null ? void 0 : h.code) === "ABORT_ERR" || (h == null ? void 0 : h.name) === "TimeoutError" && !((i = r.signal) === null || i === void 0) && i.aborted || !ns.includes(r.method)) throw h;
        if (s && n < ss) {
          let c = pr(n);
          n++, await yr(c, r.signal);
          continue;
        }
        throw h;
      }
      if (An(r.method, u.status, n, s)) {
        var a, o;
        let h = (a = (o = u.headers) === null || o === void 0 ? void 0 : o.get("Retry-After")) !== null && a !== void 0 ? a : null, c = h !== null ? Math.max(0, parseInt(h, 10) || 0) * 1e3 : pr(n);
        await u.text(), n++, await yr(c, r.signal);
        continue;
      }
      return u;
    }
  }
  var On = class {
    constructor(t) {
      var e, r, s, n, i;
      this.shouldThrowOnError = false, this.retryEnabled = true, this.method = t.method, this.url = t.url, this.headers = new Headers(t.headers), this.schema = t.schema, this.body = t.body, this.shouldThrowOnError = (e = t.shouldThrowOnError) !== null && e !== void 0 ? e : false, this.signal = t.signal, this.isMaybeSingle = (r = t.isMaybeSingle) !== null && r !== void 0 ? r : false, this.shouldStripNulls = (s = t.shouldStripNulls) !== null && s !== void 0 ? s : false, this.urlLengthLimit = (n = t.urlLengthLimit) !== null && n !== void 0 ? n : 8e3, this.retryEnabled = (i = t.retry) !== null && i !== void 0 ? i : true, t.fetch ? this.fetch = t.fetch : this.fetch = fetch;
    }
    throwOnError() {
      return this.shouldThrowOnError = true, this;
    }
    stripNulls() {
      if (this.headers.get("Accept") === "text/csv") throw new Error("stripNulls() cannot be used with csv()");
      return this.shouldStripNulls = true, this;
    }
    setHeader(t, e) {
      return this.headers = new Headers(this.headers), this.headers.set(t, e), this;
    }
    retry(t) {
      return this.retryEnabled = t, this;
    }
    then(t, e) {
      var r = this;
      if (this.schema === void 0 || (["GET", "HEAD"].includes(this.method) ? this.headers.set("Accept-Profile", this.schema) : this.headers.set("Content-Profile", this.schema)), this.method !== "GET" && this.method !== "HEAD" && this.headers.set("Content-Type", "application/json"), this.shouldStripNulls) {
        let i = this.headers.get("Accept");
        i === "application/vnd.pgrst.object+json" ? this.headers.set("Accept", "application/vnd.pgrst.object+json;nulls=stripped") : (!i || i === "application/json") && this.headers.set("Accept", "application/vnd.pgrst.array+json;nulls=stripped");
      }
      let s = this.fetch, n = (async () => {
        let i = {};
        r.headers.forEach((o, l) => {
          i[l] = o;
        });
        let a = await is(s, r.url.toString(), { method: r.method, headers: i, body: JSON.stringify(r.body, (o, l) => typeof l == "bigint" ? l.toString() : l), signal: r.signal }, r.retryEnabled);
        return await r.processResponse(a);
      })();
      return this.shouldThrowOnError || (n = n.catch((i) => {
        var a;
        let o = "", l = "", u = "", h = i == null ? void 0 : i.cause;
        if (h) {
          var c, f, d, m;
          let E = (c = h == null ? void 0 : h.message) !== null && c !== void 0 ? c : "", k = (f = h == null ? void 0 : h.code) !== null && f !== void 0 ? f : "";
          o = "".concat((d = i == null ? void 0 : i.name) !== null && d !== void 0 ? d : "FetchError", ": ").concat(i == null ? void 0 : i.message), o += "\n\nCaused by: ".concat((m = h == null ? void 0 : h.name) !== null && m !== void 0 ? m : "Error", ": ").concat(E), k && (o += " (".concat(k, ")")), h != null && h.stack && (o += "\n".concat(h.stack));
        } else {
          var g;
          o = (g = i == null ? void 0 : i.stack) !== null && g !== void 0 ? g : "";
        }
        let y = this.url.toString().length;
        return (i == null ? void 0 : i.name) === "AbortError" || (i == null ? void 0 : i.code) === "ABORT_ERR" ? (u = "", l = "Request was aborted (timeout or manual cancellation)", y > this.urlLengthLimit && (l += ". Note: Your request URL is ".concat(y, " characters, which may exceed server limits. If selecting many fields, consider using views. If filtering with large arrays (e.g., .in('id', [many IDs])), consider using an RPC function to pass values server-side."))) : ((h == null ? void 0 : h.name) === "HeadersOverflowError" || (h == null ? void 0 : h.code) === "UND_ERR_HEADERS_OVERFLOW") && (u = "", l = "HTTP headers exceeded server limits (typically 16KB)", y > this.urlLengthLimit && (l += ". Your request URL is ".concat(y, " characters. If selecting many fields, consider using views. If filtering with large arrays (e.g., .in('id', [200+ IDs])), consider using an RPC function instead."))), { success: false, error: { message: "".concat((a = i == null ? void 0 : i.name) !== null && a !== void 0 ? a : "FetchError", ": ").concat(i == null ? void 0 : i.message), details: o, hint: l, code: u }, data: null, count: null, status: 0, statusText: "" };
      })), n.then(t, e);
    }
    async processResponse(t) {
      var e = this;
      let r = null, s = null, n = null, i = t.status, a = t.statusText;
      if (t.ok) {
        var o, l;
        if (e.method !== "HEAD") {
          var u;
          let d = await t.text();
          if (d !== "") if (e.headers.get("Accept") === "text/csv") s = d;
          else if (e.headers.get("Accept") && !((u = e.headers.get("Accept")) === null || u === void 0) && u.includes("application/vnd.pgrst.plan+text")) s = d;
          else try {
            s = JSON.parse(d);
          } catch (m) {
            if (r = { message: d }, s = null, e.shouldThrowOnError) throw new ke({ message: d, details: "", hint: "", code: "" });
          }
        }
        let c = (o = e.headers.get("Prefer")) === null || o === void 0 ? void 0 : o.match(/count=(exact|planned|estimated)/), f = (l = t.headers.get("content-range")) === null || l === void 0 ? void 0 : l.split("/");
        if (c && f && f.length > 1 && (n = parseInt(f[1])), e.isMaybeSingle && Array.isArray(s)) if (s.length > 1) {
          if (r = { code: "PGRST116", details: "Results contain ".concat(s.length, " rows, application/vnd.pgrst.object+json requires 1 row"), hint: null, message: "JSON object requested, multiple (or no) rows returned" }, s = null, n = null, i = 406, a = "Not Acceptable", e.shouldThrowOnError) {
            var h;
            throw new ke(ce(ce({}, r), {}, { hint: (h = r.hint) !== null && h !== void 0 ? h : "" }));
          }
        } else s.length === 1 ? s = s[0] : s = null;
      } else {
        let c = await t.text();
        try {
          r = JSON.parse(c), Array.isArray(r) && t.status === 404 && (s = [], r = null, i = 200, a = "OK");
        } catch (f) {
          t.status === 404 && c === "" ? (i = 204, a = "No Content") : r = { message: c };
        }
        if (r && e.shouldThrowOnError) throw new ke(r);
      }
      return { success: r === null, error: r, data: s, count: n, status: i, statusText: a };
    }
    returns() {
      return this;
    }
    overrideTypes() {
      return this;
    }
  };
  var In = class extends On {
    throwOnError() {
      return super.throwOnError();
    }
    select(t) {
      let e = false, r = (t != null ? t : "*").split("").map((s) => /\s/.test(s) && !e ? "" : (s === '"' && (e = !e), s)).join("");
      return this.url.searchParams.set("select", r), this.headers.append("Prefer", "return=representation"), this;
    }
    order(t, { ascending: e = true, nullsFirst: r, foreignTable: s, referencedTable: n = s } = {}) {
      let i = n ? "".concat(n, ".order") : "order", a = this.url.searchParams.get(i);
      return this.url.searchParams.set(i, "".concat(a ? "".concat(a, ",") : "").concat(t, ".").concat(e ? "asc" : "desc").concat(r === void 0 ? "" : r ? ".nullsfirst" : ".nullslast")), this;
    }
    limit(t, { foreignTable: e, referencedTable: r = e } = {}) {
      let s = typeof r == "undefined" ? "limit" : "".concat(r, ".limit");
      return this.url.searchParams.set(s, "".concat(t)), this;
    }
    range(t, e, { foreignTable: r, referencedTable: s = r } = {}) {
      let n = typeof s == "undefined" ? "offset" : "".concat(s, ".offset"), i = typeof s == "undefined" ? "limit" : "".concat(s, ".limit");
      return this.url.searchParams.set(n, "".concat(t)), this.url.searchParams.set(i, "".concat(e - t + 1)), this;
    }
    abortSignal(t) {
      return this.signal = t, this;
    }
    single() {
      return this.headers.set("Accept", "application/vnd.pgrst.object+json"), this;
    }
    maybeSingle() {
      return this.isMaybeSingle = true, this;
    }
    csv() {
      return this.headers.set("Accept", "text/csv"), this;
    }
    geojson() {
      return this.headers.set("Accept", "application/geo+json"), this;
    }
    explain({ analyze: t = false, verbose: e = false, settings: r = false, buffers: s = false, wal: n = false, format: i = "text" } = {}) {
      var a;
      let o = [t ? "analyze" : null, e ? "verbose" : null, r ? "settings" : null, s ? "buffers" : null, n ? "wal" : null].filter(Boolean).join("|"), l = (a = this.headers.get("Accept")) !== null && a !== void 0 ? a : "application/json";
      return this.headers.set("Accept", "application/vnd.pgrst.plan+".concat(i, '; for="').concat(l, '"; options=').concat(o, ";")), i === "json" ? this : this;
    }
    rollback() {
      return this.headers.append("Prefer", "tx=rollback"), this;
    }
    returns() {
      return this;
    }
    maxAffected(t) {
      return this.headers.append("Prefer", "handling=strict"), this.headers.append("Prefer", "max-affected=".concat(t)), this;
    }
  };
  var mr = new RegExp("[,()]");
  var ve = class extends In {
    throwOnError() {
      return super.throwOnError();
    }
    eq(t, e) {
      return this.url.searchParams.append(t, "eq.".concat(e)), this;
    }
    neq(t, e) {
      return this.url.searchParams.append(t, "neq.".concat(e)), this;
    }
    gt(t, e) {
      return this.url.searchParams.append(t, "gt.".concat(e)), this;
    }
    gte(t, e) {
      return this.url.searchParams.append(t, "gte.".concat(e)), this;
    }
    lt(t, e) {
      return this.url.searchParams.append(t, "lt.".concat(e)), this;
    }
    lte(t, e) {
      return this.url.searchParams.append(t, "lte.".concat(e)), this;
    }
    like(t, e) {
      return this.url.searchParams.append(t, "like.".concat(e)), this;
    }
    likeAllOf(t, e) {
      return this.url.searchParams.append(t, "like(all).{".concat(e.join(","), "}")), this;
    }
    likeAnyOf(t, e) {
      return this.url.searchParams.append(t, "like(any).{".concat(e.join(","), "}")), this;
    }
    ilike(t, e) {
      return this.url.searchParams.append(t, "ilike.".concat(e)), this;
    }
    ilikeAllOf(t, e) {
      return this.url.searchParams.append(t, "ilike(all).{".concat(e.join(","), "}")), this;
    }
    ilikeAnyOf(t, e) {
      return this.url.searchParams.append(t, "ilike(any).{".concat(e.join(","), "}")), this;
    }
    regexMatch(t, e) {
      return this.url.searchParams.append(t, "match.".concat(e)), this;
    }
    regexIMatch(t, e) {
      return this.url.searchParams.append(t, "imatch.".concat(e)), this;
    }
    is(t, e) {
      return this.url.searchParams.append(t, "is.".concat(e)), this;
    }
    isDistinct(t, e) {
      return this.url.searchParams.append(t, "isdistinct.".concat(e)), this;
    }
    in(t, e) {
      let r = Array.from(new Set(e)).map((s) => typeof s == "string" && mr.test(s) ? '"'.concat(s, '"') : "".concat(s)).join(",");
      return this.url.searchParams.append(t, "in.(".concat(r, ")")), this;
    }
    notIn(t, e) {
      let r = Array.from(new Set(e)).map((s) => typeof s == "string" && mr.test(s) ? '"'.concat(s, '"') : "".concat(s)).join(",");
      return this.url.searchParams.append(t, "not.in.(".concat(r, ")")), this;
    }
    contains(t, e) {
      return typeof e == "string" ? this.url.searchParams.append(t, "cs.".concat(e)) : Array.isArray(e) ? this.url.searchParams.append(t, "cs.{".concat(e.join(","), "}")) : this.url.searchParams.append(t, "cs.".concat(JSON.stringify(e))), this;
    }
    containedBy(t, e) {
      return typeof e == "string" ? this.url.searchParams.append(t, "cd.".concat(e)) : Array.isArray(e) ? this.url.searchParams.append(t, "cd.{".concat(e.join(","), "}")) : this.url.searchParams.append(t, "cd.".concat(JSON.stringify(e))), this;
    }
    rangeGt(t, e) {
      return this.url.searchParams.append(t, "sr.".concat(e)), this;
    }
    rangeGte(t, e) {
      return this.url.searchParams.append(t, "nxl.".concat(e)), this;
    }
    rangeLt(t, e) {
      return this.url.searchParams.append(t, "sl.".concat(e)), this;
    }
    rangeLte(t, e) {
      return this.url.searchParams.append(t, "nxr.".concat(e)), this;
    }
    rangeAdjacent(t, e) {
      return this.url.searchParams.append(t, "adj.".concat(e)), this;
    }
    overlaps(t, e) {
      return typeof e == "string" ? this.url.searchParams.append(t, "ov.".concat(e)) : this.url.searchParams.append(t, "ov.{".concat(e.join(","), "}")), this;
    }
    textSearch(t, e, { config: r, type: s } = {}) {
      let n = "";
      s === "plain" ? n = "pl" : s === "phrase" ? n = "ph" : s === "websearch" && (n = "w");
      let i = r === void 0 ? "" : "(".concat(r, ")");
      return this.url.searchParams.append(t, "".concat(n, "fts").concat(i, ".").concat(e)), this;
    }
    match(t) {
      return Object.entries(t).filter(([e, r]) => r !== void 0).forEach(([e, r]) => {
        this.url.searchParams.append(e, "eq.".concat(r));
      }), this;
    }
    not(t, e, r) {
      return this.url.searchParams.append(t, "not.".concat(e, ".").concat(r)), this;
    }
    or(t, { foreignTable: e, referencedTable: r = e } = {}) {
      let s = r ? "".concat(r, ".or") : "or";
      return this.url.searchParams.append(s, "(".concat(t, ")")), this;
    }
    filter(t, e, r) {
      return this.url.searchParams.append(t, "".concat(e, ".").concat(r)), this;
    }
  };
  var jn = class {
    constructor(t, { headers: e = {}, schema: r, fetch: s, urlLengthLimit: n = 8e3, retry: i }) {
      this.url = t, this.headers = new Headers(e), this.schema = r, this.fetch = s, this.urlLengthLimit = n, this.retry = i;
    }
    cloneRequestState() {
      return { url: new URL(this.url.toString()), headers: new Headers(this.headers) };
    }
    select(t, e) {
      let { head: r = false, count: s } = e != null ? e : {}, n = r ? "HEAD" : "GET", i = false, a = (t != null ? t : "*").split("").map((u) => /\s/.test(u) && !i ? "" : (u === '"' && (i = !i), u)).join(""), { url: o, headers: l } = this.cloneRequestState();
      return o.searchParams.set("select", a), s && l.append("Prefer", "count=".concat(s)), new ve({ method: n, url: o, headers: l, schema: this.schema, fetch: this.fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
    insert(t, { count: e, defaultToNull: r = true } = {}) {
      var s;
      let n = "POST", { url: i, headers: a } = this.cloneRequestState();
      if (e && a.append("Prefer", "count=".concat(e)), r || a.append("Prefer", "missing=default"), Array.isArray(t)) {
        let o = t.reduce((l, u) => l.concat(Object.keys(u)), []);
        if (o.length > 0) {
          let l = [...new Set(o)].map((u) => '"'.concat(u, '"'));
          i.searchParams.set("columns", l.join(","));
        }
      }
      return new ve({ method: n, url: i, headers: a, schema: this.schema, body: t, fetch: (s = this.fetch) !== null && s !== void 0 ? s : fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
    upsert(t, { onConflict: e, ignoreDuplicates: r = false, count: s, defaultToNull: n = true } = {}) {
      var i;
      let a = "POST", { url: o, headers: l } = this.cloneRequestState();
      if (l.append("Prefer", "resolution=".concat(r ? "ignore" : "merge", "-duplicates")), e !== void 0 && o.searchParams.set("on_conflict", e), s && l.append("Prefer", "count=".concat(s)), n || l.append("Prefer", "missing=default"), Array.isArray(t)) {
        let u = t.reduce((h, c) => h.concat(Object.keys(c)), []);
        if (u.length > 0) {
          let h = [...new Set(u)].map((c) => '"'.concat(c, '"'));
          o.searchParams.set("columns", h.join(","));
        }
      }
      return new ve({ method: a, url: o, headers: l, schema: this.schema, body: t, fetch: (i = this.fetch) !== null && i !== void 0 ? i : fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
    update(t, { count: e } = {}) {
      var r;
      let s = "PATCH", { url: n, headers: i } = this.cloneRequestState();
      return e && i.append("Prefer", "count=".concat(e)), new ve({ method: s, url: n, headers: i, schema: this.schema, body: t, fetch: (r = this.fetch) !== null && r !== void 0 ? r : fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
    delete({ count: t } = {}) {
      var e;
      let r = "DELETE", { url: s, headers: n } = this.cloneRequestState();
      return t && n.append("Prefer", "count=".concat(t)), new ve({ method: r, url: s, headers: n, schema: this.schema, fetch: (e = this.fetch) !== null && e !== void 0 ? e : fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
  };
  function Pn(t, e) {
    try {
      let a = JSON.parse(t);
      if (a && typeof a == "object" && !Array.isArray(a)) {
        var r, s, n, i;
        return new ke({ message: String((r = a.message) !== null && r !== void 0 ? r : t), details: (s = a.details) !== null && s !== void 0 ? s : "", hint: (n = a.hint) !== null && n !== void 0 ? n : "", code: (i = a.code) !== null && i !== void 0 ? i : "" });
      }
    } catch (a) {
    }
    return new ke({ message: t || e, details: "", hint: "", code: "" });
  }
  function wr(t, e, r) {
    var s;
    let n = t;
    return { success: false, error: new ke({ message: "".concat((s = n == null ? void 0 : n.name) !== null && s !== void 0 ? s : "FetchError", ": ").concat(n == null ? void 0 : n.message), details: "", hint: "", code: "" }), data: null, count: null, status: e, statusText: r };
  }
  var Cn = class as {
    constructor(e, { headers: r = {}, schema: s, fetch: n, timeout: i, urlLengthLimit: a = 8e3, retry: o } = {}) {
      this.url = e, this.headers = new Headers(r), this.schemaName = s, this.urlLengthLimit = a;
      let l = n != null ? n : globalThis.fetch;
      i !== void 0 && i > 0 ? this.fetch = (u, h) => {
        let c = new AbortController(), f = setTimeout(() => c.abort(), i), d = h == null ? void 0 : h.signal;
        if (d) {
          if (d.aborted) return clearTimeout(f), l(u, h);
          let m = () => {
            clearTimeout(f), c.abort();
          };
          return d.addEventListener("abort", m, { once: true }), l(u, ce(ce({}, h), {}, { signal: c.signal })).finally(() => {
            clearTimeout(f), d.removeEventListener("abort", m);
          });
        }
        return l(u, ce(ce({}, h), {}, { signal: c.signal })).finally(() => clearTimeout(f));
      } : this.fetch = l, this.retry = o;
    }
    from(e) {
      if (!e || typeof e != "string" || e.trim() === "") throw new Error("Invalid relation name: relation must be a non-empty string.");
      return new jn(new URL("".concat(this.url, "/").concat(e)), { headers: new Headers(this.headers), schema: this.schemaName, fetch: this.fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
    schema(e) {
      return new as(this.url, { headers: this.headers, schema: e, fetch: this.fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
    async getOpenApiSpec() {
      var e = this, r;
      let s = new Headers(e.headers);
      s.set("Accept", "application/openapi+json"), e.schemaName && s.set("Accept-Profile", e.schemaName);
      let n = {};
      s.forEach((u, h) => {
        n[h] = u;
      });
      let i = (r = e.fetch) !== null && r !== void 0 ? r : globalThis.fetch, a;
      try {
        var o;
        a = await is(i, "".concat(e.url, "/"), { method: "GET", headers: n }, (o = e.retry) !== null && o !== void 0 ? o : true);
      } catch (u) {
        return wr(u, 0, "");
      }
      let l;
      try {
        l = await a.text();
      } catch (u) {
        return wr(u, a.status, a.statusText);
      }
      if (a.ok) try {
        return { success: true, error: null, data: JSON.parse(l), count: null, status: a.status, statusText: a.statusText };
      } catch (u) {
      }
      return { success: false, error: Pn(l, a.statusText), data: null, count: null, status: a.status, statusText: a.statusText };
    }
    rpc(e, r = {}, { head: s = false, get: n = false, count: i } = {}) {
      var a;
      let o, l = new URL("".concat(this.url, "/rpc/").concat(e)), u, h = (d) => d !== null && typeof d == "object" && (!Array.isArray(d) || d.some(h)), c = s && Object.values(r).some(h);
      c ? (o = "POST", u = r) : s || n ? (o = s ? "HEAD" : "GET", Object.entries(r).filter(([d, m]) => m !== void 0).map(([d, m]) => [d, Array.isArray(m) ? "{".concat(m.join(","), "}") : "".concat(m)]).forEach(([d, m]) => {
        l.searchParams.append(d, m);
      })) : (o = "POST", u = r);
      let f = new Headers(this.headers);
      return c ? f.set("Prefer", i ? "count=".concat(i, ",return=minimal") : "return=minimal") : i && f.set("Prefer", "count=".concat(i)), new ve({ method: o, url: l, headers: f, schema: this.schemaName, body: u, fetch: (a = this.fetch) !== null && a !== void 0 ? a : fetch, urlLengthLimit: this.urlLengthLimit, retry: this.retry });
    }
  };
  var $n = class {
    constructor() {
    }
    static detectEnvironment() {
      var t;
      if (typeof WebSocket != "undefined") return { type: "native", wsConstructor: WebSocket };
      let e = globalThis;
      if (typeof globalThis != "undefined" && typeof e.WebSocket != "undefined") return { type: "native", wsConstructor: e.WebSocket };
      let r = typeof globalThis != "undefined" ? globalThis : void 0;
      if (r && typeof r.WebSocket != "undefined") return { type: "native", wsConstructor: r.WebSocket };
      if (typeof globalThis != "undefined" && typeof e.WebSocketPair != "undefined" && typeof globalThis.WebSocket == "undefined") return { type: "cloudflare", error: "Cloudflare Workers detected. WebSocket clients are not supported in Cloudflare Workers.", workaround: "Use Cloudflare Workers WebSocket API for server-side WebSocket handling, or deploy to a different runtime." };
      if (typeof globalThis != "undefined" && e.EdgeRuntime || typeof navigator != "undefined" && !((t = navigator.userAgent) === null || t === void 0) && t.includes("Vercel-Edge")) return { type: "unsupported", error: "Edge runtime detected (Vercel Edge/Netlify Edge). WebSockets are not supported in edge functions.", workaround: "Use serverless functions or a different deployment target for WebSocket functionality." };
      let s = globalThis.process;
      if (s) {
        let n = s.versions;
        if (n && n.node) return { type: "unsupported", error: "Node.js detected but native WebSocket not found.", workaround: "Ensure you are running Node.js 22+ or provide a WebSocket implementation via the transport option." };
      }
      return { type: "unsupported", error: "Unknown JavaScript runtime without WebSocket support.", workaround: "Ensure you're running in a supported environment (browser, Node.js, Deno) or provide a custom WebSocket implementation." };
    }
    static getWebSocketConstructor() {
      let t = this.detectEnvironment();
      if (t.wsConstructor) return t.wsConstructor;
      let e = t.error || "WebSocket not supported in this environment.";
      throw t.workaround && (e += "\n\nSuggested solution: ".concat(t.workaround)), new Error(e);
    }
    static isWebSocketSupported() {
      try {
        return this.detectEnvironment().type === "native";
      } catch (t) {
        return false;
      }
    }
  };
  var Nn = $n;
  var xn = "2.118.0";
  var Ln = "realtime-js/".concat(xn);
  var Un = "1.0.0";
  var os = "2.0.0";
  var Bn = os;
  var Dn = 1e4;
  var qn = 15e3;
  var Mn = 1e4;
  var Fn = 100;
  var re = { closed: "closed", errored: "errored", joined: "joined", joining: "joining", leaving: "leaving" };
  var ls = { close: "phx_close", error: "phx_error", join: "phx_join", reply: "phx_reply", leave: "phx_leave", access_token: "access_token" };
  var $t = { connecting: "connecting", open: "open", closing: "closing", closed: "closed" };
  var Hn = class {
    constructor(t) {
      this.HEADER_LENGTH = 1, this.USER_BROADCAST_PUSH_META_LENGTH = 6, this.KINDS = { userBroadcastPush: 3, userBroadcast: 4 }, this.BINARY_ENCODING = 0, this.JSON_ENCODING = 1, this.BROADCAST_EVENT = "broadcast", this.allowedMetadataKeys = [], this.allowedMetadataKeys = t != null ? t : [];
    }
    encode(t, e) {
      if (t.event === this.BROADCAST_EVENT && !(t.payload instanceof ArrayBuffer) && typeof t.payload.event == "string") return e(this._binaryEncodeUserBroadcastPush(t));
      let r = [t.join_ref, t.ref, t.topic, t.event, t.payload];
      return e(JSON.stringify(r));
    }
    _binaryEncodeUserBroadcastPush(t) {
      var e;
      return this._isArrayBuffer((e = t.payload) === null || e === void 0 ? void 0 : e.payload) ? this._encodeBinaryUserBroadcastPush(t) : this._encodeJsonUserBroadcastPush(t);
    }
    _encodeBinaryUserBroadcastPush(t) {
      var e, r;
      let s = (r = (e = t.payload) === null || e === void 0 ? void 0 : e.payload) !== null && r !== void 0 ? r : new ArrayBuffer(0);
      return this._encodeUserBroadcastPush(t, this.BINARY_ENCODING, s);
    }
    _encodeJsonUserBroadcastPush(t) {
      var e, r;
      let s = (r = (e = t.payload) === null || e === void 0 ? void 0 : e.payload) !== null && r !== void 0 ? r : {}, n = new TextEncoder().encode(JSON.stringify(s)).buffer;
      return this._encodeUserBroadcastPush(t, this.JSON_ENCODING, n);
    }
    _encodeUserBroadcastPush(t, e, r) {
      var s, n;
      let i = new TextEncoder(), a = i.encode(t.topic), o = i.encode((s = t.ref) !== null && s !== void 0 ? s : ""), l = i.encode((n = t.join_ref) !== null && n !== void 0 ? n : ""), u = i.encode(t.payload.event), h = this.allowedMetadataKeys ? this._pick(t.payload, this.allowedMetadataKeys) : {}, c = i.encode(Object.keys(h).length === 0 ? "" : JSON.stringify(h));
      if (l.length > 255) throw new Error("joinRef length ".concat(l.length, " exceeds maximum of 255"));
      if (o.length > 255) throw new Error("ref length ".concat(o.length, " exceeds maximum of 255"));
      if (a.length > 255) throw new Error("topic length ".concat(a.length, " exceeds maximum of 255"));
      if (u.length > 255) throw new Error("userEvent length ".concat(u.length, " exceeds maximum of 255"));
      if (c.length > 255) throw new Error("metadata length ".concat(c.length, " exceeds maximum of 255"));
      let f = this.USER_BROADCAST_PUSH_META_LENGTH + l.length + o.length + a.length + u.length + c.length, d = new ArrayBuffer(this.HEADER_LENGTH + f), m = new DataView(d), g = new Uint8Array(d), y = 0;
      m.setUint8(y++, this.KINDS.userBroadcastPush), m.setUint8(y++, l.length), m.setUint8(y++, o.length), m.setUint8(y++, a.length), m.setUint8(y++, u.length), m.setUint8(y++, c.length), m.setUint8(y++, e), g.set(l, y), y += l.length, g.set(o, y), y += o.length, g.set(a, y), y += a.length, g.set(u, y), y += u.length, g.set(c, y), y += c.length;
      var E = new Uint8Array(d.byteLength + r.byteLength);
      return E.set(new Uint8Array(d), 0), E.set(new Uint8Array(r), d.byteLength), E.buffer;
    }
    decode(t, e) {
      if (this._isArrayBuffer(t)) {
        let r = this._binaryDecode(t);
        return e(r);
      }
      if (typeof t == "string") {
        let r = JSON.parse(t), [s, n, i, a, o] = r;
        return e({ join_ref: s, ref: n, topic: i, event: a, payload: o });
      }
      return e({});
    }
    _binaryDecode(t) {
      let e = new DataView(t), r = e.getUint8(0), s = new TextDecoder();
      if (r === this.KINDS.userBroadcast) return this._decodeUserBroadcast(t, e, s);
    }
    _decodeUserBroadcast(t, e, r) {
      let s = e.getUint8(1), n = e.getUint8(2), i = e.getUint8(3), a = e.getUint8(4), o = this.HEADER_LENGTH + 4, l = r.decode(t.slice(o, o + s));
      o = o + s;
      let u = r.decode(t.slice(o, o + n));
      o = o + n;
      let h = r.decode(t.slice(o, o + i));
      o = o + i;
      let c = t.slice(o, t.byteLength), f = a === this.JSON_ENCODING ? JSON.parse(r.decode(c)) : c, d = { type: this.BROADCAST_EVENT, event: u, payload: f };
      return i > 0 && (d.meta = JSON.parse(h)), { join_ref: null, ref: null, topic: l, event: this.BROADCAST_EVENT, payload: d };
    }
    _isArrayBuffer(t) {
      var e;
      return t instanceof ArrayBuffer || ((e = t == null ? void 0 : t.constructor) === null || e === void 0 ? void 0 : e.name) === "ArrayBuffer";
    }
    _pick(t, e) {
      return !t || typeof t != "object" ? {} : Object.fromEntries(Object.entries(t).filter(([r]) => e.includes(r)));
    }
  };
  var T;
  (function(t) {
    t.abstime = "abstime", t.bool = "bool", t.date = "date", t.daterange = "daterange", t.float4 = "float4", t.float8 = "float8", t.int2 = "int2", t.int4 = "int4", t.int4range = "int4range", t.int8 = "int8", t.int8range = "int8range", t.json = "json", t.jsonb = "jsonb", t.money = "money", t.numeric = "numeric", t.oid = "oid", t.reltime = "reltime", t.text = "text", t.time = "time", t.timestamp = "timestamp", t.timestamptz = "timestamptz", t.timetz = "timetz", t.tsrange = "tsrange", t.tstzrange = "tstzrange";
  })(T || (T = {}));
  var br = (t, e, r = {}) => {
    var s;
    let n = (s = r.skipTypes) !== null && s !== void 0 ? s : [];
    return e ? Object.keys(e).reduce((i, a) => (i[a] = Wn(a, t, e, n), i), {}) : {};
  };
  var Wn = (t, e, r, s) => {
    let n = e.find((o) => o.name === t), i = n == null ? void 0 : n.type, a = r[t];
    return i && !s.includes(i) ? us(i, a) : Nt(a);
  };
  var us = (t, e) => {
    if (t.charAt(0) === "_") {
      let r = t.slice(1, t.length);
      return Vn(e, r);
    }
    switch (t) {
      case T.bool:
        return Kn(e);
      case T.float4:
      case T.float8:
      case T.int2:
      case T.int4:
      case T.int8:
      case T.numeric:
      case T.oid:
        return Gn(e);
      case T.json:
      case T.jsonb:
        return Jn(e);
      case T.timestamp:
        return zn(e);
      case T.abstime:
      case T.date:
      case T.daterange:
      case T.int4range:
      case T.int8range:
      case T.money:
      case T.reltime:
      case T.text:
      case T.time:
      case T.timestamptz:
      case T.timetz:
      case T.tsrange:
      case T.tstzrange:
        return Nt(e);
      default:
        return Nt(e);
    }
  };
  var Nt = (t) => t;
  var Kn = (t) => {
    switch (t) {
      case "t":
        return true;
      case "f":
        return false;
      default:
        return t;
    }
  };
  var Gn = (t) => {
    if (typeof t == "string") {
      let e = parseFloat(t);
      if (!Number.isNaN(e)) return e;
    }
    return t;
  };
  var Jn = (t) => {
    if (typeof t == "string") try {
      return JSON.parse(t);
    } catch (e) {
      return t;
    }
    return t;
  };
  var Vn = (t, e) => {
    if (typeof t != "string") return t;
    let r = t.length - 1, s = t[r];
    if (t[0] === "{" && s === "}") {
      let n, i = t.slice(1, r);
      try {
        n = JSON.parse("[" + i + "]");
      } catch (a) {
        n = i ? i.split(",") : [];
      }
      return n.map((a) => us(e, a));
    }
    return t;
  };
  var zn = (t) => typeof t == "string" ? t.replace(" ", "T") : t;
  var hs = (t) => {
    let e = new URL(t);
    return e.protocol = e.protocol.replace(/^ws/i, "http"), e.pathname = e.pathname.replace(/\/+$/, "").replace(/\/socket\/websocket$/i, "").replace(/\/socket$/i, "").replace(/\/websocket$/i, ""), e.pathname === "" || e.pathname === "/" ? e.pathname = "/api/broadcast" : e.pathname = e.pathname + "/api/broadcast", e.href;
  };
  var Ee = (t) => typeof t == "function" ? t : function() {
    return t;
  };
  var Yn = typeof self != "undefined" ? self : null;
  var _e = typeof window != "undefined" ? window : null;
  var J = Yn || _e || globalThis;
  var Xn = "2.0.0";
  var Qn = 1e4;
  var Zn = 1e3;
  var ei = 100;
  var V = { connecting: 0, open: 1, closing: 2, closed: 3 };
  var L = { closed: "closed", errored: "errored", joined: "joined", joining: "joining", leaving: "leaving" };
  var Z = { close: "phx_close", error: "phx_error", join: "phx_join", reply: "phx_reply", leave: "phx_leave" };
  var xt = { longpoll: "longpoll", websocket: "websocket" };
  var ti = { complete: 4 };
  var Lt = "base64url.bearer.phx.";
  var Ge = class {
    constructor(t, e, r, s) {
      this.channel = t, this.event = e, this.payload = r || function() {
        return {};
      }, this.receivedResp = null, this.timeout = s, this.timeoutTimer = null, this.recHooks = [], this.sent = false, this.ref = void 0;
    }
    resend(t) {
      this.timeout = t, this.reset(), this.send();
    }
    send() {
      this.hasReceived("timeout") || (this.startTimeout(), this.sent = true, this.channel.socket.push({ topic: this.channel.topic, event: this.event, payload: this.payload(), ref: this.ref, join_ref: this.channel.joinRef() }));
    }
    receive(t, e) {
      return this.hasReceived(t) && e(this.receivedResp.response), this.recHooks.push({ status: t, callback: e }), this;
    }
    reset() {
      this.cancelRefEvent(), this.ref = null, this.refEvent = null, this.receivedResp = null, this.sent = false;
    }
    destroy() {
      this.cancelRefEvent(), this.cancelTimeout();
    }
    matchReceive({ status: t, response: e, _ref: r }) {
      this.recHooks.filter((s) => s.status === t).forEach((s) => s.callback(e));
    }
    cancelRefEvent() {
      this.refEvent && this.channel.off(this.refEvent);
    }
    cancelTimeout() {
      clearTimeout(this.timeoutTimer), this.timeoutTimer = null;
    }
    startTimeout() {
      this.timeoutTimer && this.cancelTimeout(), this.ref = this.channel.socket.makeRef(), this.refEvent = this.channel.replyEventName(this.ref), this.channel.on(this.refEvent, (t) => {
        this.cancelRefEvent(), this.cancelTimeout(), this.receivedResp = t, this.matchReceive(t);
      }), this.timeoutTimer = setTimeout(() => {
        this.trigger("timeout", {});
      }, this.timeout);
    }
    hasReceived(t) {
      return this.receivedResp && this.receivedResp.status === t;
    }
    trigger(t, e) {
      this.channel.trigger(this.refEvent, { status: t, response: e });
    }
  };
  var cs = class {
    constructor(t, e) {
      this.callback = t, this.timerCalc = e, this.timer = void 0, this.tries = 0;
    }
    reset() {
      this.tries = 0, clearTimeout(this.timer);
    }
    scheduleTimeout() {
      clearTimeout(this.timer), this.timer = setTimeout(() => {
        this.tries = this.tries + 1, this.callback();
      }, this.timerCalc(this.tries + 1));
    }
  };
  var ri = class {
    constructor(t, e, r) {
      this.state = L.closed, this.topic = t, this.params = Ee(e || {}), this.socket = r, this.bindings = [], this.bindingRef = 0, this.timeout = this.socket.timeout, this.joinedOnce = false, this.joinPush = new Ge(this, Z.join, this.params, this.timeout), this.pushBuffer = [], this.stateChangeRefs = [], this.rejoinTimer = new cs(() => {
        this.socket.isConnected() && this.rejoin();
      }, this.socket.rejoinAfterMs), this.stateChangeRefs.push(this.socket.onError(() => this.rejoinTimer.reset())), this.stateChangeRefs.push(this.socket.onOpen(() => {
        this.rejoinTimer.reset(), this.isErrored() && this.rejoin();
      })), this.joinPush.receive("ok", () => {
        this.state = L.joined, this.rejoinTimer.reset(), this.pushBuffer.forEach((s) => s.send()), this.pushBuffer = [];
      }), this.joinPush.receive("error", (s) => {
        this.state = L.errored, this.socket.hasLogger() && this.socket.log("channel", "error ".concat(this.topic), s), this.socket.isConnected() && this.rejoinTimer.scheduleTimeout();
      }), this.onClose(() => {
        this.rejoinTimer.reset(), this.socket.hasLogger() && this.socket.log("channel", "close ".concat(this.topic)), this.state = L.closed, this.socket.remove(this);
      }), this.onError((s) => {
        this.socket.hasLogger() && this.socket.log("channel", "error ".concat(this.topic), s), this.isJoining() && this.joinPush.reset(), this.state = L.errored, this.socket.isConnected() && this.rejoinTimer.scheduleTimeout();
      }), this.joinPush.receive("timeout", () => {
        this.socket.hasLogger() && this.socket.log("channel", "timeout ".concat(this.topic), this.joinPush.timeout), new Ge(this, Z.leave, Ee({}), this.timeout).send(), this.state = L.errored, this.joinPush.reset(), this.socket.isConnected() && this.rejoinTimer.scheduleTimeout();
      }), this.on(Z.reply, (s, n) => {
        this.trigger(this.replyEventName(n), s);
      });
    }
    join(t = this.timeout) {
      if (this.joinedOnce) throw new Error("tried to join multiple times. 'join' can only be called a single time per channel instance");
      return this.timeout = t, this.joinedOnce = true, this.rejoin(), this.joinPush;
    }
    teardown() {
      this.pushBuffer.forEach((t) => t.destroy()), this.pushBuffer = [], this.rejoinTimer.reset(), this.joinPush.destroy(), this.state = L.closed, this.bindings = [];
    }
    onClose(t) {
      this.on(Z.close, t);
    }
    onError(t) {
      return this.on(Z.error, (e) => t(e));
    }
    on(t, e) {
      let r = this.bindingRef++;
      return this.bindings.push({ event: t, ref: r, callback: e }), r;
    }
    off(t, e) {
      this.bindings = this.bindings.filter((r) => !(r.event === t && (typeof e == "undefined" || e === r.ref)));
    }
    canPush() {
      return this.socket.isConnected() && this.isJoined();
    }
    push(t, e, r = this.timeout) {
      if (e = e || {}, !this.joinedOnce) throw new Error("tried to push '".concat(t, "' to '").concat(this.topic, "' before joining. Use channel.join() before pushing events"));
      let s = new Ge(this, t, function() {
        return e;
      }, r);
      return this.canPush() ? s.send() : (s.startTimeout(), this.pushBuffer.push(s)), s;
    }
    leave(t = this.timeout) {
      this.rejoinTimer.reset(), this.joinPush.cancelTimeout(), this.state = L.leaving;
      let e = () => {
        this.socket.hasLogger() && this.socket.log("channel", "leave ".concat(this.topic)), this.trigger(Z.close, "leave");
      }, r = new Ge(this, Z.leave, Ee({}), t);
      return r.receive("ok", () => e()).receive("timeout", () => e()), r.send(), this.canPush() || r.trigger("ok", {}), r;
    }
    onMessage(t, e, r) {
      return e;
    }
    filterBindings(t, e, r) {
      return true;
    }
    isMember(t, e, r, s) {
      return this.topic !== t ? false : s && s !== this.joinRef() ? (this.socket.hasLogger() && this.socket.log("channel", "dropping outdated message", { topic: t, event: e, payload: r, joinRef: s }), false) : true;
    }
    joinRef() {
      return this.joinPush.ref;
    }
    rejoin(t = this.timeout) {
      this.isLeaving() || (this.socket.leaveOpenTopic(this.topic), this.state = L.joining, this.joinPush.resend(t));
    }
    trigger(t, e, r, s) {
      let n = this.onMessage(t, e, r, s);
      if (e && !n) throw new Error("channel onMessage callbacks must return the payload, modified or unmodified");
      let i = this.bindings.filter((a) => a.event === t && this.filterBindings(a, e, r));
      for (let a = 0; a < i.length; a++) i[a].callback(n, r, s || this.joinRef());
    }
    replyEventName(t) {
      return "chan_reply_".concat(t);
    }
    isClosed() {
      return this.state === L.closed;
    }
    isErrored() {
      return this.state === L.errored;
    }
    isJoined() {
      return this.state === L.joined;
    }
    isJoining() {
      return this.state === L.joining;
    }
    isLeaving() {
      return this.state === L.leaving;
    }
  };
  var nt = class {
    static request(t, e, r, s, n, i, a) {
      if (J.XDomainRequest) {
        let o = new J.XDomainRequest();
        return this.xdomainRequest(o, t, e, s, n, i, a);
      } else if (J.XMLHttpRequest) {
        let o = new J.XMLHttpRequest();
        return this.xhrRequest(o, t, e, r, s, n, i, a);
      } else {
        if (J.fetch && J.AbortController) return this.fetchRequest(t, e, r, s, n, i, a);
        throw new Error("No suitable XMLHttpRequest implementation found");
      }
    }
    static fetchRequest(t, e, r, s, n, i, a) {
      let o = { method: t, headers: r, body: s }, l = null;
      if (n) {
        l = new AbortController();
        let u = setTimeout(() => l.abort(), n);
        o.signal = l.signal;
      }
      return J.fetch(e, o).then((u) => u.text()).then((u) => this.parseJSON(u)).then((u) => a && a(u)).catch((u) => {
        u.name === "AbortError" && i ? i() : a && a(null);
      }), l;
    }
    static xdomainRequest(t, e, r, s, n, i, a) {
      return t.timeout = n, t.open(e, r), t.onload = () => {
        let o = this.parseJSON(t.responseText);
        a && a(o);
      }, i && (t.ontimeout = i), t.onprogress = () => {
      }, t.send(s), t;
    }
    static xhrRequest(t, e, r, s, n, i, a, o) {
      t.open(e, r, true), t.timeout = i;
      for (let [l, u] of Object.entries(s)) t.setRequestHeader(l, u);
      return t.onerror = () => o && o(null), t.onreadystatechange = () => {
        if (t.readyState === ti.complete && o) {
          let l = this.parseJSON(t.responseText);
          o(l);
        }
      }, a && (t.ontimeout = a), t.send(n), t;
    }
    static parseJSON(t) {
      if (!t || t === "") return null;
      try {
        return JSON.parse(t);
      } catch (e) {
        return console && console.log("failed to parse JSON response", t), null;
      }
    }
    static serialize(t, e) {
      let r = [];
      for (var s in t) {
        if (!Object.prototype.hasOwnProperty.call(t, s)) continue;
        let n = e ? "".concat(e, "[").concat(s, "]") : s, i = t[s];
        typeof i == "object" ? r.push(this.serialize(i, n)) : r.push(encodeURIComponent(n) + "=" + encodeURIComponent(i));
      }
      return r.join("&");
    }
    static appendParams(t, e) {
      if (Object.keys(e).length === 0) return t;
      let r = t.match(/\?/) ? "&" : "?";
      return "".concat(t).concat(r).concat(this.serialize(e));
    }
  };
  var si = (t) => {
    let e = "", r = new Uint8Array(t), s = r.byteLength;
    for (let n = 0; n < s; n++) e += String.fromCharCode(r[n]);
    return btoa(e);
  };
  var ye = class {
    constructor(t, e) {
      e && e.length === 2 && e[1].startsWith(Lt) && (this.authToken = atob(e[1].slice(Lt.length))), this.endPoint = null, this.token = null, this.skipHeartbeat = true, this.reqs = /* @__PURE__ */ new Set(), this.awaitingBatchAck = false, this.currentBatch = null, this.currentBatchTimer = null, this.batchBuffer = [], this.onopen = function() {
      }, this.onerror = function() {
      }, this.onmessage = function() {
      }, this.onclose = function() {
      }, this.pollEndpoint = this.normalizeEndpoint(t), this.readyState = V.connecting, setTimeout(() => this.poll(), 0);
    }
    normalizeEndpoint(t) {
      return t.replace("ws://", "http://").replace("wss://", "https://").replace(new RegExp("(.*)/" + xt.websocket), "$1/" + xt.longpoll);
    }
    endpointURL() {
      return nt.appendParams(this.pollEndpoint, { token: this.token });
    }
    closeAndRetry(t, e, r) {
      this.close(t, e, r), this.readyState = V.connecting;
    }
    ontimeout() {
      this.onerror("timeout"), this.closeAndRetry(1005, "timeout", false);
    }
    isActive() {
      return this.readyState === V.open || this.readyState === V.connecting;
    }
    poll() {
      let t = { Accept: "application/json" };
      this.authToken && (t["X-Phoenix-AuthToken"] = this.authToken), this.ajax("GET", t, null, () => this.ontimeout(), (e) => {
        if (e) {
          var { status: r, token: s, messages: n } = e;
          if (r === 410 && this.token !== null) {
            this.onerror(410), this.closeAndRetry(3410, "session_gone", false);
            return;
          }
          this.token = s;
        } else r = 0;
        switch (r) {
          case 200:
            n.forEach((i) => {
              setTimeout(() => this.onmessage({ data: i }), 0);
            }), this.poll();
            break;
          case 204:
            this.poll();
            break;
          case 410:
            this.readyState = V.open, this.onopen({}), this.poll();
            break;
          case 403:
            this.onerror(403), this.close(1008, "forbidden", false);
            break;
          case 0:
          case 500:
            this.onerror(500), this.closeAndRetry(1011, "internal server error", 500);
            break;
          default:
            throw new Error("unhandled poll status ".concat(r));
        }
      });
    }
    send(t) {
      typeof t != "string" && (t = si(t)), this.currentBatch ? this.currentBatch.push(t) : this.awaitingBatchAck ? this.batchBuffer.push(t) : (this.currentBatch = [t], this.currentBatchTimer = setTimeout(() => {
        this.batchSend(this.currentBatch), this.currentBatch = null;
      }, 0));
    }
    batchSend(t, e = 0) {
      this.awaitingBatchAck = true;
      let r = e + ei, s = t.slice(e, r);
      this.ajax("POST", { "Content-Type": "application/x-ndjson" }, s.join("\n"), () => this.onerror("timeout"), (n) => {
        !n || n.status !== 200 ? (this.awaitingBatchAck = false, this.onerror(n && n.status), this.closeAndRetry(1011, "internal server error", false)) : r < t.length ? this.batchSend(t, r) : this.batchBuffer.length > 0 ? (this.batchSend(this.batchBuffer), this.batchBuffer = []) : this.awaitingBatchAck = false;
      });
    }
    close(t, e, r) {
      for (let n of this.reqs) n.abort();
      this.readyState = V.closed;
      let s = Object.assign({ code: 1e3, reason: void 0, wasClean: true }, { code: t, reason: e, wasClean: r });
      this.batchBuffer = [], clearTimeout(this.currentBatchTimer), this.currentBatchTimer = null, typeof CloseEvent != "undefined" ? this.onclose(new CloseEvent("close", s)) : this.onclose(s);
    }
    ajax(t, e, r, s, n) {
      let i, a = () => {
        this.reqs.delete(i), s();
      };
      i = nt.request(t, this.endpointURL(), e, r, this.timeout, a, (o) => {
        this.reqs.delete(i), this.isActive() && n(o);
      }), this.reqs.add(i);
    }
  };
  var ni = class Ce {
    constructor(e, r = {}) {
      let s = r.events || { state: "presence_state", diff: "presence_diff" };
      this.state = /* @__PURE__ */ Object.create(null), this.pendingDiffs = [], this.channel = e, this.joinRef = null, this.caller = { onJoin: function() {
      }, onLeave: function() {
      }, onSync: function() {
      } }, this.channel.on(s.state, (n) => {
        let { onJoin: i, onLeave: a, onSync: o } = this.caller;
        this.joinRef = this.channel.joinRef(), this.state = Ce.syncState(this.state, n, i, a), this.pendingDiffs.forEach((l) => {
          this.state = Ce.syncDiff(this.state, l, i, a);
        }), this.pendingDiffs = [], o();
      }), this.channel.on(s.diff, (n) => {
        let { onJoin: i, onLeave: a, onSync: o } = this.caller;
        this.inPendingSyncState() ? this.pendingDiffs.push(n) : (this.state = Ce.syncDiff(this.state, n, i, a), o());
      });
    }
    onJoin(e) {
      this.caller.onJoin = e;
    }
    onLeave(e) {
      this.caller.onLeave = e;
    }
    onSync(e) {
      this.caller.onSync = e;
    }
    list(e) {
      return Ce.list(this.state, e);
    }
    inPendingSyncState() {
      return !this.joinRef || this.joinRef !== this.channel.joinRef();
    }
    static syncState(e, r, s, n) {
      let i = this.toNullProtoObj(this.clone(e));
      r = this.toNullProtoObj(r);
      let a = /* @__PURE__ */ Object.create(null), o = /* @__PURE__ */ Object.create(null);
      return this.map(i, (l, u) => {
        r[l] || (o[l] = u);
      }), this.map(r, (l, u) => {
        let h = i[l];
        if (h) {
          let c = u.metas.map((g) => g.phx_ref), f = h.metas.map((g) => g.phx_ref), d = u.metas.filter((g) => f.indexOf(g.phx_ref) < 0), m = h.metas.filter((g) => c.indexOf(g.phx_ref) < 0);
          d.length > 0 && (a[l] = u, a[l].metas = d), m.length > 0 && (o[l] = this.clone(h), o[l].metas = m);
        } else a[l] = u;
      }), this.syncDiff(i, { joins: a, leaves: o }, s, n);
    }
    static syncDiff(e, r, s, n) {
      e = this.toNullProtoObj(e);
      let { joins: i, leaves: a } = this.clone(r);
      return s || (s = function() {
      }), n || (n = function() {
      }), this.map(i, (o, l) => {
        let u = e[o];
        if (e[o] = this.clone(l), u) {
          let h = e[o].metas.map((f) => f.phx_ref), c = u.metas.filter((f) => h.indexOf(f.phx_ref) < 0);
          e[o].metas.unshift(...c);
        }
        s(o, u, l);
      }), this.map(a, (o, l) => {
        let u = e[o];
        if (!u) return;
        let h = l.metas.map((c) => c.phx_ref);
        u.metas = u.metas.filter((c) => h.indexOf(c.phx_ref) < 0), n(o, u, l), u.metas.length === 0 && delete e[o];
      }), e;
    }
    static list(e, r) {
      return r || (r = function(s, n) {
        return n;
      }), this.map(e, (s, n) => r(s, n));
    }
    static map(e, r) {
      return Object.getOwnPropertyNames(e).map((s) => r(s, e[s]));
    }
    static toNullProtoObj(e) {
      if (Object.getPrototypeOf(e) === null) return e;
      let r = /* @__PURE__ */ Object.create(null);
      return Object.getOwnPropertyNames(e).forEach((s) => {
        r[s] = e[s];
      }), r;
    }
    static clone(e) {
      return JSON.parse(JSON.stringify(e));
    }
  };
  var Je = { HEADER_LENGTH: 1, META_LENGTH: 4, KINDS: { push: 0, reply: 1, broadcast: 2 }, encode(t, e) {
    if (t.payload.constructor === ArrayBuffer) return e(this.binaryEncode(t));
    {
      let r = [t.join_ref, t.ref, t.topic, t.event, t.payload];
      return e(JSON.stringify(r));
    }
  }, decode(t, e) {
    if (t.constructor === ArrayBuffer) return e(this.binaryDecode(t));
    {
      let [r, s, n, i, a] = JSON.parse(t);
      return e({ join_ref: r, ref: s, topic: n, event: i, payload: a });
    }
  }, binaryEncode(t) {
    let { join_ref: e, ref: r, event: s, topic: n, payload: i } = t, a = new TextEncoder(), o = a.encode(e), l = a.encode(r), u = a.encode(n), h = a.encode(s);
    this.assertFieldSize(o.byteLength, "join_ref"), this.assertFieldSize(l.byteLength, "ref"), this.assertFieldSize(u.byteLength, "topic"), this.assertFieldSize(h.byteLength, "event");
    let c = this.META_LENGTH + o.byteLength + l.byteLength + u.byteLength + h.byteLength, f = new ArrayBuffer(this.HEADER_LENGTH + c), d = new Uint8Array(f), m = new DataView(f), g = 0;
    m.setUint8(g++, this.KINDS.push), m.setUint8(g++, o.byteLength), m.setUint8(g++, l.byteLength), m.setUint8(g++, u.byteLength), m.setUint8(g++, h.byteLength), d.set(o, g), g += o.byteLength, d.set(l, g), g += l.byteLength, d.set(u, g), g += u.byteLength, d.set(h, g), g += h.byteLength;
    var y = new Uint8Array(f.byteLength + i.byteLength);
    return y.set(d, 0), y.set(new Uint8Array(i), f.byteLength), y.buffer;
  }, assertFieldSize(t, e) {
    if (t > 255) throw new Error("unable to convert ".concat(e, " to binary: must be less than or equal to 255 bytes, but is ").concat(t, " bytes"));
  }, binaryDecode(t) {
    let e = new DataView(t), r = e.getUint8(0), s = new TextDecoder();
    switch (r) {
      case this.KINDS.push:
        return this.decodePush(t, e, s);
      case this.KINDS.reply:
        return this.decodeReply(t, e, s);
      case this.KINDS.broadcast:
        return this.decodeBroadcast(t, e, s);
    }
  }, decodePush(t, e, r) {
    let s = e.getUint8(1), n = e.getUint8(2), i = e.getUint8(3), a = this.HEADER_LENGTH + this.META_LENGTH - 1, o = r.decode(t.slice(a, a + s));
    a = a + s;
    let l = r.decode(t.slice(a, a + n));
    a = a + n;
    let u = r.decode(t.slice(a, a + i));
    a = a + i;
    let h = t.slice(a, t.byteLength);
    return { join_ref: o, ref: null, topic: l, event: u, payload: h };
  }, decodeReply(t, e, r) {
    let s = e.getUint8(1), n = e.getUint8(2), i = e.getUint8(3), a = e.getUint8(4), o = this.HEADER_LENGTH + this.META_LENGTH, l = r.decode(t.slice(o, o + s));
    o = o + s;
    let u = r.decode(t.slice(o, o + n));
    o = o + n;
    let h = r.decode(t.slice(o, o + i));
    o = o + i;
    let c = r.decode(t.slice(o, o + a));
    o = o + a;
    let f = t.slice(o, t.byteLength), d = { status: c, response: f };
    return { join_ref: l, ref: u, topic: h, event: Z.reply, payload: d };
  }, decodeBroadcast(t, e, r) {
    let s = e.getUint8(1), n = e.getUint8(2), i = this.HEADER_LENGTH + 2, a = r.decode(t.slice(i, i + s));
    i = i + s;
    let o = r.decode(t.slice(i, i + n));
    i = i + n;
    let l = t.slice(i, t.byteLength);
    return { join_ref: null, ref: null, topic: a, event: o, payload: l };
  } };
  var ii = class {
    constructor(t, e = {}) {
      var r, s;
      this.stateChangeCallbacks = { open: [], close: [], error: [], message: [] }, this.channels = [], this.sendBuffer = [], this.ref = 0, this.fallbackRef = null, this.timeout = e.timeout || Qn, this.transport = e.transport || J.WebSocket || ye, this.conn = void 0, this.primaryPassedHealthCheck = false, this.longPollFallbackMs = e.longPollFallbackMs, this.fallbackTimer = null;
      let n = null;
      try {
        n = J && J.sessionStorage;
      } catch (a) {
      }
      this.sessionStore = e.sessionStorage || n, this.establishedConnections = 0, this.defaultEncoder = Je.encode.bind(Je), this.defaultDecoder = Je.decode.bind(Je), this.closeWasClean = true, this.disconnecting = false, this.binaryType = e.binaryType || "arraybuffer", this.connectClock = 1, this.pageHidden = false, this.encode = void 0, this.decode = void 0, this.transport !== ye ? (this.encode = e.encode || this.defaultEncoder, this.decode = e.decode || this.defaultDecoder) : (this.encode = this.defaultEncoder, this.decode = this.defaultDecoder);
      let i = null;
      _e && _e.addEventListener && (_e.addEventListener("pagehide", (a) => {
        this.conn && (this.disconnect(), i = this.connectClock);
      }), _e.addEventListener("pageshow", (a) => {
        i === this.connectClock && (i = null, this.connect());
      }), _e.addEventListener("visibilitychange", () => {
        document.visibilityState === "hidden" ? this.pageHidden = true : (this.pageHidden = false, !this.isConnected() && !this.closeWasClean && this.teardown(() => this.connect()));
      })), this.heartbeatIntervalMs = e.heartbeatIntervalMs || 3e4, this.autoSendHeartbeat = (r = e.autoSendHeartbeat) != null ? r : true, this.heartbeatCallback = (s = e.heartbeatCallback) != null ? s : (() => {
      }), this.rejoinAfterMs = (a) => e.rejoinAfterMs ? e.rejoinAfterMs(a) : [1e3, 2e3, 5e3][a - 1] || 1e4, this.reconnectAfterMs = (a) => e.reconnectAfterMs ? e.reconnectAfterMs(a) : [10, 50, 100, 150, 200, 250, 500, 1e3, 2e3][a - 1] || 5e3, this.logger = e.logger || null, !this.logger && e.debug && (this.logger = (a, o, l) => {
        console.log("".concat(a, ": ").concat(o), l);
      }), this.longpollerTimeout = e.longpollerTimeout || 2e4, this.params = Ee(e.params || {}), this.endPoint = "".concat(t, "/").concat(xt.websocket), this.vsn = e.vsn || Xn, this.heartbeatTimeoutTimer = null, this.heartbeatTimer = null, this.heartbeatSentAt = null, this.pendingHeartbeatRef = null, this.reconnectTimer = new cs(() => {
        if (this.pageHidden) {
          this.log("Not reconnecting as page is hidden!"), this.teardown();
          return;
        }
        this.teardown(async () => {
          e.beforeReconnect && await e.beforeReconnect(), this.connect();
        });
      }, this.reconnectAfterMs), this.authToken = e.authToken && Ee(e.authToken);
    }
    getLongPollTransport() {
      return ye;
    }
    replaceTransport(t) {
      this.connectClock++, this.closeWasClean = true, clearTimeout(this.fallbackTimer), this.reconnectTimer.reset(), this.conn && (this.conn.close(), this.conn = null), this.transport = t;
    }
    protocol() {
      return location.protocol.match(/^https/) ? "wss" : "ws";
    }
    endPointURL() {
      let t = nt.appendParams(nt.appendParams(this.endPoint, this.params()), { vsn: this.vsn });
      return t.charAt(0) !== "/" ? t : t.charAt(1) === "/" ? "".concat(this.protocol(), ":").concat(t) : "".concat(this.protocol(), "://").concat(location.host).concat(t);
    }
    disconnect(t, e, r) {
      this.connectClock++, this.disconnecting = true, this.closeWasClean = true, clearTimeout(this.fallbackTimer), this.reconnectTimer.reset(), this.teardown(() => {
        this.disconnecting = false, t && t();
      }, e, r);
    }
    connect(t) {
      t && (console && console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor"), this.params = Ee(t)), !(this.conn && !this.disconnecting) && (this.longPollFallbackMs && this.transport !== ye ? this.connectWithFallback(ye, this.longPollFallbackMs) : this.transportConnect());
    }
    log(t, e, r) {
      this.logger && this.logger(t, e, r);
    }
    hasLogger() {
      return this.logger !== null;
    }
    onOpen(t) {
      let e = this.makeRef();
      return this.stateChangeCallbacks.open.push([e, t]), e;
    }
    onClose(t) {
      let e = this.makeRef();
      return this.stateChangeCallbacks.close.push([e, t]), e;
    }
    onError(t) {
      let e = this.makeRef();
      return this.stateChangeCallbacks.error.push([e, t]), e;
    }
    onMessage(t) {
      let e = this.makeRef();
      return this.stateChangeCallbacks.message.push([e, t]), e;
    }
    onHeartbeat(t) {
      this.heartbeatCallback = t;
    }
    ping(t) {
      if (!this.isConnected()) return false;
      let e = this.makeRef(), r = Date.now();
      this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref: e });
      let s = this.onMessage((n) => {
        n.ref === e && (this.off([s]), t(Date.now() - r));
      });
      return true;
    }
    transportName(t) {
      return t === ye ? "LongPoll" : t.name;
    }
    transportConnect() {
      this.connectClock++, this.closeWasClean = false;
      let t;
      this.authToken && (t = ["phoenix", "".concat(Lt).concat(btoa(this.authToken()).replace(/=/g, ""))]), this.conn = new this.transport(this.endPointURL(), t), this.conn.binaryType = this.binaryType, this.conn.timeout = this.longpollerTimeout, this.conn.onopen = () => this.onConnOpen(), this.conn.onerror = (e) => this.onConnError(e), this.conn.onmessage = (e) => this.onConnMessage(e), this.conn.onclose = (e) => this.onConnClose(e);
    }
    getSession(t) {
      return this.sessionStore && this.sessionStore.getItem(t);
    }
    storeSession(t, e) {
      this.sessionStore && this.sessionStore.setItem(t, e);
    }
    connectWithFallback(t, e = 2500) {
      clearTimeout(this.fallbackTimer);
      let r = false, s = true, n, i, a = this.transportName(t), o = (l) => {
        this.log("transport", "falling back to ".concat(a, "..."), l), this.off([n, i]), s = false, this.replaceTransport(t), this.transportConnect();
      };
      if (this.getSession("phx:fallback:".concat(a))) return o("memorized");
      this.fallbackTimer = setTimeout(o, e), i = this.onError((l) => {
        this.log("transport", "error", l), s && !r && (clearTimeout(this.fallbackTimer), o(l));
      }), this.fallbackRef && this.off([this.fallbackRef]), this.fallbackRef = this.onOpen(() => {
        if (r = true, !s) {
          let l = this.transportName(t);
          return this.primaryPassedHealthCheck || this.storeSession("phx:fallback:".concat(l), "true"), this.log("transport", "established ".concat(l, " fallback"));
        }
        clearTimeout(this.fallbackTimer), this.fallbackTimer = setTimeout(o, e), this.ping((l) => {
          this.log("transport", "connected to primary after", l), this.primaryPassedHealthCheck = true, clearTimeout(this.fallbackTimer);
        });
      }), this.transportConnect();
    }
    clearHeartbeats() {
      clearTimeout(this.heartbeatTimer), clearTimeout(this.heartbeatTimeoutTimer);
    }
    onConnOpen() {
      this.hasLogger() && this.log("transport", "connected to ".concat(this.endPointURL())), this.closeWasClean = false, this.disconnecting = false, this.establishedConnections++, this.flushSendBuffer(), this.reconnectTimer.reset(), this.autoSendHeartbeat && this.resetHeartbeat(), this.triggerStateCallbacks("open");
    }
    heartbeatTimeout() {
      if (this.pendingHeartbeatRef) {
        this.pendingHeartbeatRef = null, this.heartbeatSentAt = null, this.hasLogger() && this.log("transport", "heartbeat timeout. Attempting to re-establish connection");
        try {
          this.heartbeatCallback("timeout");
        } catch (t) {
          this.log("error", "error in heartbeat callback", t);
        }
        this.triggerChanError(new Error("heartbeat timeout")), this.closeWasClean = false, this.teardown(() => this.reconnectTimer.scheduleTimeout(), Zn, "heartbeat timeout");
      }
    }
    resetHeartbeat() {
      this.conn && this.conn.skipHeartbeat || (this.pendingHeartbeatRef = null, this.clearHeartbeats(), this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs));
    }
    teardown(t, e, r) {
      if (!this.conn) return t && t();
      let s = this.conn;
      this.waitForBufferDone(s, () => {
        e ? s.close(e, r || "") : s.close(), this.waitForSocketClosed(s, () => {
          this.conn === s && (this.conn.onopen = function() {
          }, this.conn.onerror = function() {
          }, this.conn.onmessage = function() {
          }, this.conn.onclose = function() {
          }, this.conn = null), t && t();
        });
      });
    }
    waitForBufferDone(t, e, r = 1) {
      if (r === 5 || !t.bufferedAmount) {
        e();
        return;
      }
      setTimeout(() => {
        this.waitForBufferDone(t, e, r + 1);
      }, 150 * r);
    }
    waitForSocketClosed(t, e, r = 1) {
      if (r === 5 || t.readyState === V.closed) {
        e();
        return;
      }
      setTimeout(() => {
        this.waitForSocketClosed(t, e, r + 1);
      }, 150 * r);
    }
    onConnClose(t) {
      this.conn && (this.conn.onclose = () => {
      }), this.hasLogger() && this.log("transport", "close", t), this.triggerChanError(t), this.clearHeartbeats(), this.closeWasClean || this.reconnectTimer.scheduleTimeout(), this.triggerStateCallbacks("close", t);
    }
    onConnError(t) {
      this.hasLogger() && this.log("transport", "error", t);
      let e = this.transport, r = this.establishedConnections;
      this.triggerStateCallbacks("error", t, e, r), (e === this.transport || r > 0) && this.triggerChanError(t);
    }
    triggerChanError(t) {
      this.channels.forEach((e) => {
        e.isErrored() || e.isLeaving() || e.isClosed() || e.trigger(Z.error, t);
      });
    }
    connectionState() {
      switch (this.conn && this.conn.readyState) {
        case V.connecting:
          return "connecting";
        case V.open:
          return "open";
        case V.closing:
          return "closing";
        default:
          return "closed";
      }
    }
    isConnected() {
      return this.connectionState() === "open";
    }
    remove(t) {
      this.off(t.stateChangeRefs), this.channels = this.channels.filter((e) => e !== t);
    }
    off(t) {
      for (let e in this.stateChangeCallbacks) this.stateChangeCallbacks[e] = this.stateChangeCallbacks[e].filter(([r]) => t.indexOf(r) === -1);
    }
    channel(t, e = {}) {
      let r = new ri(t, e, this);
      return this.channels.push(r), r;
    }
    push(t) {
      if (this.hasLogger()) {
        let { topic: e, event: r, payload: s, ref: n, join_ref: i } = t;
        this.log("push", "".concat(e, " ").concat(r, " (").concat(i, ", ").concat(n, ")"), s);
      }
      this.isConnected() ? this.encode(t, (e) => this.conn.send(e)) : this.sendBuffer.push(() => this.encode(t, (e) => this.conn.send(e)));
    }
    makeRef() {
      let t = this.ref + 1;
      return t === this.ref ? this.ref = 0 : this.ref = t, this.ref.toString();
    }
    sendHeartbeat() {
      if (!this.isConnected()) {
        try {
          this.heartbeatCallback("disconnected");
        } catch (t) {
          this.log("error", "error in heartbeat callback", t);
        }
        return;
      }
      if (this.pendingHeartbeatRef) {
        this.heartbeatTimeout();
        return;
      }
      this.pendingHeartbeatRef = this.makeRef(), this.heartbeatSentAt = Date.now(), this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref: this.pendingHeartbeatRef });
      try {
        this.heartbeatCallback("sent");
      } catch (t) {
        this.log("error", "error in heartbeat callback", t);
      }
      this.heartbeatTimeoutTimer = setTimeout(() => this.heartbeatTimeout(), this.heartbeatIntervalMs);
    }
    flushSendBuffer() {
      this.isConnected() && this.sendBuffer.length > 0 && (this.sendBuffer.forEach((t) => t()), this.sendBuffer = []);
    }
    onConnMessage(t) {
      this.decode(t.data, (e) => {
        let { topic: r, event: s, payload: n, ref: i, join_ref: a } = e;
        if (i && i === this.pendingHeartbeatRef) {
          let o = this.heartbeatSentAt ? Date.now() - this.heartbeatSentAt : void 0;
          this.clearHeartbeats();
          try {
            this.heartbeatCallback(n.status === "ok" ? "ok" : "error", o);
          } catch (l) {
            this.log("error", "error in heartbeat callback", l);
          }
          this.pendingHeartbeatRef = null, this.heartbeatSentAt = null, this.autoSendHeartbeat && (this.heartbeatTimer = setTimeout(() => this.sendHeartbeat(), this.heartbeatIntervalMs));
        }
        this.hasLogger() && this.log("receive", "".concat(n.status || "", " ").concat(r, " ").concat(s, " ").concat(i && "(" + i + ")" || "").trim(), n);
        for (let o = 0; o < this.channels.length; o++) {
          let l = this.channels[o];
          l.isMember(r, s, n, a) && l.trigger(s, n, i, a);
        }
        this.triggerStateCallbacks("message", e);
      });
    }
    triggerStateCallbacks(t, ...e) {
      try {
        this.stateChangeCallbacks[t].forEach(([r, s]) => {
          try {
            s(...e);
          } catch (n) {
            this.log("error", "error in ".concat(t, " callback"), n);
          }
        });
      } catch (r) {
        this.log("error", "error triggering ".concat(t, " callbacks"), r);
      }
    }
    leaveOpenTopic(t) {
      let e = this.channels.find((r) => r.topic === t && (r.isJoined() || r.isJoining()));
      e && (this.hasLogger() && this.log("transport", 'leaving duplicate topic "'.concat(t, '"')), e.leave());
    }
  };
  var ai = class et {
    constructor(e, r) {
      let s = li(r);
      this.presence = new ni(e.getChannel(), s), this.presence.onJoin((n, i, a) => {
        let o = et.onJoinPayload(n, i, a);
        e.getChannel().trigger("presence", o);
      }), this.presence.onLeave((n, i, a) => {
        let o = et.onLeavePayload(n, i, a);
        e.getChannel().trigger("presence", o);
      }), this.presence.onSync(() => {
        e.getChannel().trigger("presence", { event: "sync" });
      });
    }
    get state() {
      return et.transformState(this.presence.state);
    }
    static transformState(e) {
      return e = oi(e), Object.getOwnPropertyNames(e).reduce((r, s) => {
        let n = e[s];
        return r[s] = tt(n), r;
      }, {});
    }
    static onJoinPayload(e, r, s) {
      let n = vr(r), i = tt(s);
      return { event: "join", key: e, currentPresences: n, newPresences: i };
    }
    static onLeavePayload(e, r, s) {
      let n = vr(r), i = tt(s);
      return { event: "leave", key: e, currentPresences: n, leftPresences: i };
    }
  };
  function tt(t) {
    return t.metas.map((e) => {
      let r = Object.getOwnPropertyDescriptors(e), s = Object.defineProperties({}, r);
      return s.presence_ref = s.phx_ref, delete s.phx_ref, delete s.phx_ref_prev, s;
    });
  }
  function oi(t) {
    return JSON.parse(JSON.stringify(t));
  }
  function li(t) {
    return (t == null ? void 0 : t.events) && { events: t.events };
  }
  function vr(t) {
    return t != null && t.metas ? tt(t) : [];
  }
  var _r;
  (function(t) {
    t.SYNC = "sync", t.JOIN = "join", t.LEAVE = "leave";
  })(_r || (_r = {}));
  var ui = class {
    get state() {
      return this.presenceAdapter.state;
    }
    constructor(t, e) {
      this.channel = t, this.presenceAdapter = new ai(this.channel.channelAdapter, e);
    }
  };
  function hi(t) {
    if (t instanceof Error) return t;
    if (typeof t == "string") return new Error(t);
    if (t && typeof t == "object") {
      let e = t;
      if (typeof e.code == "number") {
        let r = typeof e.reason == "string" && e.reason ? " (".concat(e.reason, ")") : "";
        return new Error("socket closed: ".concat(e.code).concat(r), { cause: t });
      }
      return new Error("channel error: transport failure", { cause: t });
    }
    return new Error("channel error: connection lost");
  }
  var ci = class {
    constructor(t, e, r) {
      let s = di(r);
      this.channel = t.getSocket().channel(e, s), this.socket = t;
    }
    get state() {
      return this.channel.state;
    }
    set state(t) {
      this.channel.state = t;
    }
    get joinedOnce() {
      return this.channel.joinedOnce;
    }
    get joinPush() {
      return this.channel.joinPush;
    }
    get rejoinTimer() {
      return this.channel.rejoinTimer;
    }
    on(t, e) {
      return this.channel.on(t, e);
    }
    off(t, e) {
      this.channel.off(t, e);
    }
    subscribe(t) {
      return this.channel.join(t);
    }
    unsubscribe(t) {
      return this.channel.leave(t);
    }
    teardown() {
      this.channel.teardown();
    }
    onClose(t) {
      this.channel.onClose(t);
    }
    onError(t) {
      return this.channel.onError(t);
    }
    push(t, e, r) {
      let s;
      try {
        s = this.channel.push(t, e, r);
      } catch (n) {
        throw new Error("tried to push '".concat(t, "' to '").concat(this.channel.topic, "' before joining. Use channel.subscribe() before pushing events"));
      }
      if (this.channel.pushBuffer.length > Fn) {
        let n = this.channel.pushBuffer.shift();
        n.cancelTimeout(), this.socket.log("channel", "discarded push due to buffer overflow: ".concat(n.event), n.payload());
      }
      return s;
    }
    updateJoinPayload(t) {
      let e = this.channel.joinPush.payload();
      this.channel.joinPush.payload = () => Object.assign(Object.assign({}, e), t);
    }
    canPush() {
      return this.socket.isConnected() && this.state === re.joined;
    }
    isJoined() {
      return this.state === re.joined;
    }
    isJoining() {
      return this.state === re.joining;
    }
    isClosed() {
      return this.state === re.closed;
    }
    isLeaving() {
      return this.state === re.leaving;
    }
    updateFilterBindings(t) {
      this.channel.filterBindings = t;
    }
    updatePayloadTransform(t) {
      this.channel.onMessage = t;
    }
    getChannel() {
      return this.channel;
    }
  };
  function di(t) {
    return { config: Object.assign({ broadcast: { ack: false, self: false }, presence: { key: "", enabled: false }, private: false }, t.config) };
  }
  var fi = /[,()"\\]/;
  var pi = (t) => fi.test(t) || t !== t.trim();
  var gi = (t) => '"'.concat(t.replace(/\\/g, "\\\\").replace(/"/g, '\\"'), '"');
  var kr = (t) => {
    let e = t === null ? "null" : String(t);
    return pi(e) ? gi(e) : e;
  };
  var yi = (t) => t === null ? "null" : String(t);
  var mi = (t, e) => {
    if (t === "in") {
      let r = Array.isArray(e) ? e : [e];
      if (r.length === 0) throw new Error("Realtime `in` filter requires at least one value.");
      return "in.(".concat(Array.from(new Set(r)).map((s) => kr(s)).join(","), ")");
    }
    return t === "is" ? "is.".concat(yi(e)) : "".concat(t, ".").concat(kr(e));
  };
  var ds = class {
    constructor() {
      this.filters = [];
    }
    add(t, e, r, s = false) {
      let n = s ? "not." : "";
      return this.filters.push("".concat(t, "=").concat(n).concat(mi(e, r))), this;
    }
    eq(t, e) {
      return this.add(t, "eq", e);
    }
    neq(t, e) {
      return this.add(t, "neq", e);
    }
    gt(t, e) {
      return this.add(t, "gt", e);
    }
    gte(t, e) {
      return this.add(t, "gte", e);
    }
    lt(t, e) {
      return this.add(t, "lt", e);
    }
    lte(t, e) {
      return this.add(t, "lte", e);
    }
    in(t, e) {
      return this.add(t, "in", e);
    }
    like(t, e) {
      return this.add(t, "like", e);
    }
    ilike(t, e) {
      return this.add(t, "ilike", e);
    }
    match(t, e) {
      return this.add(t, "match", e);
    }
    imatch(t, e) {
      return this.add(t, "imatch", e);
    }
    is(t, e) {
      return this.add(t, "is", e);
    }
    isDistinct(t, e) {
      return this.add(t, "isdistinct", e);
    }
    not(t, e, r) {
      return this.add(t, e, r, true);
    }
    build() {
      return this.filters.join(",");
    }
    toString() {
      return this.build();
    }
  };
  var Er;
  (function(t) {
    t.ALL = "*", t.INSERT = "INSERT", t.UPDATE = "UPDATE", t.DELETE = "DELETE";
  })(Er || (Er = {}));
  var he;
  (function(t) {
    t.BROADCAST = "broadcast", t.PRESENCE = "presence", t.POSTGRES_CHANGES = "postgres_changes", t.SYSTEM = "system";
  })(he || (he = {}));
  var ee;
  (function(t) {
    t.SUBSCRIBED = "SUBSCRIBED", t.TIMED_OUT = "TIMED_OUT", t.CLOSED = "CLOSED", t.CHANNEL_ERROR = "CHANNEL_ERROR";
  })(ee || (ee = {}));
  var wi = class ie {
    get state() {
      return this.channelAdapter.state;
    }
    set state(e) {
      this.channelAdapter.state = e;
    }
    get joinedOnce() {
      return this.channelAdapter.joinedOnce;
    }
    get timeout() {
      return this.socket.timeout;
    }
    get joinPush() {
      return this.channelAdapter.joinPush;
    }
    get rejoinTimer() {
      return this.channelAdapter.rejoinTimer;
    }
    constructor(e, r = { config: {} }, s) {
      var n, i;
      if (this.topic = e, this.params = r, this.socket = s, this.bindings = {}, this.subTopic = e.replace(/^realtime:/i, ""), this.params.config = Object.assign({ broadcast: { ack: false, self: false }, presence: { key: "", enabled: false }, private: false }, r.config), this.channelAdapter = new ci(this.socket.socketAdapter, e, this.params), this.presence = new ui(this), this._onClose(() => {
        this.socket._remove(this);
      }), this._updateFilterTransform(), this.broadcastEndpointURL = hs(this.socket.socketAdapter.endPointURL()), this.private = this.params.config.private || false, !this.private && !((i = (n = this.params.config) === null || n === void 0 ? void 0 : n.broadcast) === null || i === void 0) && i.replay) throw new Error("tried to use replay on public channel '".concat(this.topic, "'. It must be a private channel."));
    }
    subscribe(e, r = this.timeout) {
      var s, n, i, a;
      if (this.socket.isConnected() || this.socket.connect(), this.channelAdapter.isClosed()) {
        let { config: { broadcast: o, presence: l, private: u, postgres_changes_options: h } } = this.params, c = (n = (s = this.bindings.postgres_changes) === null || s === void 0 ? void 0 : s.map((y) => y.filter)) !== null && n !== void 0 ? n : [], f = !!this.bindings[he.PRESENCE] && this.bindings[he.PRESENCE].length > 0 || ((i = this.params.config.presence) === null || i === void 0 ? void 0 : i.enabled) === true, d = {}, m = Object.assign({ broadcast: o, presence: Object.assign(Object.assign({}, l), { enabled: f }), postgres_changes: c, private: u }, h ? { postgres_changes_options: h } : {});
        this.socket.accessTokenValue && (d.access_token = this.socket.accessTokenValue), this._onError((y) => {
          e == null || e(ee.CHANNEL_ERROR, hi(y));
        }), this._onClose(() => e == null ? void 0 : e(ee.CLOSED)), this.updateJoinPayload(Object.assign({ config: m }, d)), this._updateFilterMessage();
        let g = h != null && h.wait && c.length > 0 ? Math.max(r, ((a = h.timeout) !== null && a !== void 0 ? a : qn) + Mn) : r;
        this.channelAdapter.subscribe(g).receive("ok", async ({ postgres_changes: y }) => {
          if (this.socket._isManualToken() || this.socket.setAuth(), y === void 0) {
            e == null || e(ee.SUBSCRIBED);
            return;
          }
          this._updatePostgresBindings(y, e);
        }).receive("error", (y) => {
          this.state = re.errored;
          let E = Object.values(y).join(", ") || "error";
          e == null || e(ee.CHANNEL_ERROR, new Error(E, { cause: y }));
        }).receive("timeout", () => {
          e == null || e(ee.TIMED_OUT);
        });
      }
      return this;
    }
    _updatePostgresBindings(e, r) {
      var s;
      let n = this.bindings.postgres_changes, i = (s = n == null ? void 0 : n.length) !== null && s !== void 0 ? s : 0, a = [];
      for (let o = 0; o < i; o++) {
        let l = n[o], { filter: { event: u, schema: h, table: c, filter: f } } = l, d = e && e[o];
        if (d && d.event === u && ie.isFilterValueEqual(d.schema, h) && ie.isFilterValueEqual(d.table, c) && ie.isFilterValueEqual(d.filter, f)) a.push(Object.assign(Object.assign({}, l), { id: d.id }));
        else {
          this.unsubscribe(), this.state = re.errored, r == null || r(ee.CHANNEL_ERROR, new Error("mismatch between server and client bindings for postgres changes"));
          return;
        }
      }
      this.bindings.postgres_changes = a, this.state != re.errored && r && r(ee.SUBSCRIBED);
    }
    presenceState() {
      return this.presence.state;
    }
    async track(e, r = {}) {
      return await this.send({ type: "presence", event: "track", payload: e }, r);
    }
    async untrack(e = {}) {
      return await this.send({ type: "presence", event: "untrack" }, e);
    }
    on(e, r, s) {
      let n = this.channelAdapter.isJoined() || this.channelAdapter.isJoining(), i = e === he.PRESENCE || e === he.POSTGRES_CHANGES;
      if (n && i) throw this.socket.log("channel", "cannot add `".concat(e, "` callbacks for ").concat(this.topic, " after `subscribe()`.")), new Error("cannot add `".concat(e, "` callbacks for ").concat(this.topic, " after `subscribe()`."));
      return this._on(e, r, s);
    }
    async httpSend(e, r, s = {}) {
      var n;
      if (r == null) return Promise.reject(new Error("Payload is required for httpSend()"));
      let i = r instanceof ArrayBuffer || ArrayBuffer.isView(r), a = { apikey: this.socket.apiKey ? this.socket.apiKey : "", "Content-Type": i ? "application/octet-stream" : "application/json" };
      this.socket.accessTokenValue && (a.Authorization = "Bearer ".concat(this.socket.accessTokenValue));
      let o = new URL(this.broadcastEndpointURL);
      o.pathname += "/".concat(encodeURIComponent(this.subTopic), "/events/").concat(encodeURIComponent(e)), this.private && o.searchParams.set("private", "true");
      let l = { method: "POST", headers: a, body: i ? r : JSON.stringify(r) }, u = await this._fetchWithTimeout(o.toString(), l, (n = s.timeout) !== null && n !== void 0 ? n : this.timeout);
      if (u.status === 202) return { success: true };
      if (u.status === 404) return Promise.reject(new Error("httpSend() requires Realtime server v2.97.0 or newer; the endpoint returned 404. Update your Supabase CLI to a recent version, or upgrade the Realtime server in your self-hosted setup. See https://github.com/supabase/supabase-js/blob/master/packages/core/realtime-js/migrations/httpsend-server-version.md"));
      let h = u.statusText;
      try {
        let c = await u.json();
        h = c.error || c.message || h;
      } catch (c) {
      }
      return Promise.reject(new Error(h));
    }
    async send(e, r = {}) {
      var s, n;
      if (!this.channelAdapter.canPush() && e.type === "broadcast") {
        let i = "Realtime send() is automatically falling back to REST API. This behavior will be deprecated in the future. Please use httpSend() explicitly for REST delivery.";
        this.socket.hasLogger() ? this.socket.log("channel", i) : console.warn(i);
        let { event: a, payload: o } = e, l = { apikey: this.socket.apiKey ? this.socket.apiKey : "", "Content-Type": "application/json" };
        this.socket.accessTokenValue && (l.Authorization = "Bearer ".concat(this.socket.accessTokenValue));
        let u = { method: "POST", headers: l, body: JSON.stringify({ messages: [{ topic: this.subTopic, event: a, payload: o, private: this.private }] }) };
        try {
          let h = await this._fetchWithTimeout(this.broadcastEndpointURL, u, (s = r.timeout) !== null && s !== void 0 ? s : this.timeout);
          return await ((n = h.body) === null || n === void 0 ? void 0 : n.cancel()), h.ok ? "ok" : "error";
        } catch (h) {
          return h instanceof Error && h.name === "AbortError" ? "timed out" : "error";
        }
      } else return new Promise((i) => {
        var a, o, l;
        let u = this.channelAdapter.push(e.type, e, r.timeout || this.timeout);
        e.type === "broadcast" && !(!((l = (o = (a = this.params) === null || a === void 0 ? void 0 : a.config) === null || o === void 0 ? void 0 : o.broadcast) === null || l === void 0) && l.ack) && i("ok"), u.receive("ok", () => i("ok")), u.receive("error", () => i("error")), u.receive("timeout", () => i("timed out"));
      });
    }
    updateJoinPayload(e) {
      this.channelAdapter.updateJoinPayload(e);
    }
    async unsubscribe(e = this.timeout) {
      return new Promise((r) => {
        this.channelAdapter.unsubscribe(e).receive("ok", () => r("ok")).receive("timeout", () => r("timed out")).receive("error", () => r("error"));
      });
    }
    teardown() {
      this.channelAdapter.teardown();
    }
    async _fetchWithTimeout(e, r, s) {
      let n = new AbortController(), i = setTimeout(() => n.abort(), s), a = await this.socket.fetch(e, Object.assign(Object.assign({}, r), { signal: n.signal }));
      return clearTimeout(i), a;
    }
    _on(e, r, s) {
      var n;
      let i = e.toLocaleLowerCase(), a = r == null ? void 0 : r.filter;
      if ((a instanceof ds || typeof a == "object" && a !== null && typeof a.build == "function") && (r = Object.assign(Object.assign({}, r), { filter: a.build() })), i === he.POSTGRES_CHANGES && ((n = this.bindings[i]) === null || n === void 0 ? void 0 : n.find((u) => ie.isSamePostgresFilter(u.filter, r)))) return this.socket.log("error", "duplicate `postgres_changes` binding for ".concat(this.topic, " ignored"), r), this;
      let o = this.channelAdapter.on(e, s), l = { type: i, filter: r, callback: s, ref: o };
      return this.bindings[i] ? this.bindings[i].push(l) : this.bindings[i] = [l], this._updateFilterMessage(), this;
    }
    _onClose(e) {
      this.channelAdapter.onClose(e);
    }
    _onError(e) {
      this.channelAdapter.onError(e);
    }
    _updateFilterMessage() {
      this.channelAdapter.updateFilterBindings((e, r, s) => {
        var n, i, a, o, l, u, h;
        let c = e.event.toLocaleLowerCase();
        if (this._notThisChannelEvent(c, s)) return false;
        let f = (n = this.bindings[c]) === null || n === void 0 ? void 0 : n.find((d) => d.ref === e.ref);
        if (!f) return true;
        if (["broadcast", "presence", "postgres_changes"].includes(c)) if ("id" in f) {
          let d = f.id, m = (i = f.filter) === null || i === void 0 ? void 0 : i.event;
          return d && ((a = r.ids) === null || a === void 0 ? void 0 : a.includes(d)) && (m === "*" || (m == null ? void 0 : m.toLocaleLowerCase()) === ((o = r.data) === null || o === void 0 ? void 0 : o.type.toLocaleLowerCase()));
        } else {
          let d = (u = (l = f == null ? void 0 : f.filter) === null || l === void 0 ? void 0 : l.event) === null || u === void 0 ? void 0 : u.toLocaleLowerCase();
          return d === "*" || d === ((h = r == null ? void 0 : r.event) === null || h === void 0 ? void 0 : h.toLocaleLowerCase());
        }
        else return f.type.toLocaleLowerCase() === c;
      });
    }
    _notThisChannelEvent(e, r) {
      let { close: s, error: n, leave: i, join: a } = ls;
      return r && [s, n, i, a].includes(e) && r !== this.joinPush.ref;
    }
    _updateFilterTransform() {
      this.channelAdapter.updatePayloadTransform((e, r, s) => {
        if (typeof r == "object" && "ids" in r) {
          let n = r.data, { schema: i, table: a, commit_timestamp: o, type: l, errors: u } = n;
          return Object.assign(Object.assign({}, { schema: i, table: a, commit_timestamp: o, eventType: l, new: {}, old: {}, errors: u }), this._getPayloadRecords(n));
        }
        return r;
      });
    }
    copyBindings(e) {
      if (this.joinedOnce) throw new Error("cannot copy bindings into joined channel");
      for (let r in e.bindings) for (let s of e.bindings[r]) this._on(s.type, s.filter, s.callback);
    }
    static isFilterValueEqual(e, r) {
      let s = e != null ? e : void 0, n = r != null ? r : void 0;
      return s === n;
    }
    static isSamePostgresFilter(e, r) {
      var s, n, i, a;
      let o = (n = (s = e == null ? void 0 : e.select) === null || s === void 0 ? void 0 : s.join()) !== null && n !== void 0 ? n : void 0, l = (a = (i = r == null ? void 0 : r.select) === null || i === void 0 ? void 0 : i.join()) !== null && a !== void 0 ? a : void 0;
      return (e == null ? void 0 : e.event) === (r == null ? void 0 : r.event) && ie.isFilterValueEqual(e == null ? void 0 : e.schema, r == null ? void 0 : r.schema) && ie.isFilterValueEqual(e == null ? void 0 : e.table, r == null ? void 0 : r.table) && ie.isFilterValueEqual(e == null ? void 0 : e.filter, r == null ? void 0 : r.filter) && o === l;
    }
    _getPayloadRecords(e) {
      let r = { new: {}, old: {} };
      return (e.type === "INSERT" || e.type === "UPDATE") && (r.new = br(e.columns, e.record)), (e.type === "UPDATE" || e.type === "DELETE") && (r.old = br(e.columns, e.old_record)), r;
    }
  };
  var bi = class {
    constructor(t, e) {
      this.socket = new ii(t, e);
    }
    get timeout() {
      return this.socket.timeout;
    }
    get endPoint() {
      return this.socket.endPoint;
    }
    get transport() {
      return this.socket.transport;
    }
    get heartbeatIntervalMs() {
      return this.socket.heartbeatIntervalMs;
    }
    get heartbeatCallback() {
      return this.socket.heartbeatCallback;
    }
    set heartbeatCallback(t) {
      this.socket.heartbeatCallback = t;
    }
    get heartbeatTimer() {
      return this.socket.heartbeatTimer;
    }
    get pendingHeartbeatRef() {
      return this.socket.pendingHeartbeatRef;
    }
    get reconnectTimer() {
      return this.socket.reconnectTimer;
    }
    get vsn() {
      return this.socket.vsn;
    }
    get encode() {
      return this.socket.encode;
    }
    get decode() {
      return this.socket.decode;
    }
    get reconnectAfterMs() {
      return this.socket.reconnectAfterMs;
    }
    get sendBuffer() {
      return this.socket.sendBuffer;
    }
    get stateChangeCallbacks() {
      return this.socket.stateChangeCallbacks;
    }
    connect() {
      this.socket.connect();
    }
    disconnect(t, e, r, s = 1e4) {
      return new Promise((n) => {
        setTimeout(() => n("timeout"), s), this.socket.disconnect(() => {
          t(), n("ok");
        }, e, r);
      });
    }
    push(t) {
      this.socket.push(t);
    }
    log(t, e, r) {
      this.socket.log(t, e, r);
    }
    hasLogger() {
      return this.socket.hasLogger();
    }
    makeRef() {
      return this.socket.makeRef();
    }
    onOpen(t) {
      this.socket.onOpen(t);
    }
    onClose(t) {
      this.socket.onClose(t);
    }
    onError(t) {
      this.socket.onError(t);
    }
    onMessage(t) {
      this.socket.onMessage(t);
    }
    isConnected() {
      return this.socket.isConnected();
    }
    isConnecting() {
      return this.socket.connectionState() == $t.connecting;
    }
    isDisconnecting() {
      return this.socket.connectionState() == $t.closing;
    }
    connectionState() {
      return this.socket.connectionState();
    }
    endPointURL() {
      return this.socket.endPointURL();
    }
    sendHeartbeat() {
      this.socket.sendHeartbeat();
    }
    getSocket() {
      return this.socket;
    }
  };
  var Sr = { HEARTBEAT_INTERVAL: 25e3, RECONNECT_DELAY: 10, HEARTBEAT_TIMEOUT_FALLBACK: 100 };
  var vi = [1e3, 2e3, 5e3, 1e4];
  var _i = 1e4;
  function ki() {
    let t = /* @__PURE__ */ new Map();
    return { get length() {
      return t.size;
    }, clear() {
      t.clear();
    }, getItem(e) {
      return t.has(e) ? t.get(e) : null;
    }, key(e) {
      var r;
      return (r = Array.from(t.keys())[e]) !== null && r !== void 0 ? r : null;
    }, removeItem(e) {
      t.delete(e);
    }, setItem(e, r) {
      t.set(e, String(r));
    } };
  }
  function Ei() {
    try {
      if (typeof globalThis != "undefined" && globalThis.sessionStorage) return globalThis.sessionStorage;
    } catch (t) {
    }
    return ki();
  }
  var Si = '\n  addEventListener("message", (e) => {\n    if (e.data.event === "start") {\n      setInterval(() => postMessage({ event: "keepAlive" }), e.data.interval);\n    }\n  });';
  var Ti = class {
    get endPoint() {
      return this.socketAdapter.endPoint;
    }
    get timeout() {
      return this.socketAdapter.timeout;
    }
    get transport() {
      return this.socketAdapter.transport;
    }
    get heartbeatCallback() {
      return this.socketAdapter.heartbeatCallback;
    }
    get heartbeatIntervalMs() {
      return this.socketAdapter.heartbeatIntervalMs;
    }
    get heartbeatTimer() {
      return this.worker ? this._workerHeartbeatTimer : this.socketAdapter.heartbeatTimer;
    }
    get pendingHeartbeatRef() {
      return this.worker ? this._pendingWorkerHeartbeatRef : this.socketAdapter.pendingHeartbeatRef;
    }
    get reconnectTimer() {
      return this.socketAdapter.reconnectTimer;
    }
    get vsn() {
      return this.socketAdapter.vsn;
    }
    get encode() {
      return this.socketAdapter.encode;
    }
    get decode() {
      return this.socketAdapter.decode;
    }
    get reconnectAfterMs() {
      return this.socketAdapter.reconnectAfterMs;
    }
    get sendBuffer() {
      return this.socketAdapter.sendBuffer;
    }
    get stateChangeCallbacks() {
      return this.socketAdapter.stateChangeCallbacks;
    }
    constructor(t, e) {
      var r;
      if (this.channels = new Array(), this.accessTokenValue = null, this.accessToken = null, this.apiKey = null, this.httpEndpoint = "", this.headers = {}, this.params = {}, this.ref = 0, this.serializer = new Hn(), this._manuallySetToken = false, this._authPromise = null, this._authGeneration = 0, this._workerHeartbeatTimer = void 0, this._pendingWorkerHeartbeatRef = null, this._pendingDisconnectTimer = null, this._disconnectOnEmptyChannelsAfterMs = 0, this._resolveFetch = (n) => n ? (...i) => n(...i) : (...i) => fetch(...i), !(!((r = e == null ? void 0 : e.params) === null || r === void 0) && r.apikey)) throw new Error("API key is required to connect to Realtime");
      this.apiKey = e.params.apikey;
      let s = this._initializeOptions(e);
      this.socketAdapter = new bi(t, s), this.httpEndpoint = hs(t), this.fetch = this._resolveFetch(e == null ? void 0 : e.fetch);
    }
    connect() {
      if (!(this.isConnecting() || this.isDisconnecting() || this.isConnected())) {
        this.accessToken && !this._authPromise && this._setAuthSafely("connect"), this._setupConnectionHandlers();
        try {
          this.socketAdapter.connect();
        } catch (t) {
          let e = t.message;
          throw new Error("WebSocket not available: ".concat(e));
        }
        this._handleNodeJsRaceCondition();
      }
    }
    endpointURL() {
      return this.socketAdapter.endPointURL();
    }
    async disconnect(t, e) {
      return this._cancelPendingDisconnect(), this.isDisconnecting() ? "ok" : await this.socketAdapter.disconnect(() => {
        clearInterval(this._workerHeartbeatTimer), this._terminateWorker();
      }, t, e);
    }
    getChannels() {
      return this.channels;
    }
    async removeChannel(t) {
      let e = await t.unsubscribe();
      return e === "ok" && t.teardown(), e;
    }
    async removeAllChannels() {
      let t = this.channels.map(async (r) => {
        let s = await r.unsubscribe();
        return r.teardown(), s;
      }), e = await Promise.all(t);
      return await this.disconnect(), e;
    }
    log(t, e, r) {
      this.socketAdapter.log(t, e, r);
    }
    hasLogger() {
      return this.socketAdapter.hasLogger();
    }
    connectionState() {
      return this.socketAdapter.connectionState() || $t.closed;
    }
    isConnected() {
      return this.socketAdapter.isConnected();
    }
    isConnecting() {
      return this.socketAdapter.isConnecting();
    }
    isDisconnecting() {
      return this.socketAdapter.isDisconnecting();
    }
    channel(t, e = { config: {} }) {
      let r = "realtime:".concat(t), s = this.getChannels().find((n) => n.topic === r);
      if (s) return s;
      {
        let n = new wi("realtime:".concat(t), e, this);
        return this._cancelPendingDisconnect(), this.channels.push(n), n;
      }
    }
    push(t) {
      this.socketAdapter.push(t);
    }
    async setAuth(t = null) {
      let e = ++this._authGeneration, r = this._performAuth(t, e);
      e === this._authGeneration && (this._authPromise = r);
      try {
        await r;
      } finally {
        this._authPromise === r && (this._authPromise = null);
      }
    }
    _isManualToken() {
      return this._manuallySetToken;
    }
    async sendHeartbeat() {
      this.socketAdapter.sendHeartbeat();
    }
    onHeartbeat(t) {
      this.socketAdapter.heartbeatCallback = this._wrapHeartbeatCallback(t);
    }
    _makeRef() {
      return this.socketAdapter.makeRef();
    }
    _remove(t) {
      this.channels = this.channels.filter((e) => e.topic !== t.topic), this.channels.length === 0 && (this.log("transport", "no channels remaining, scheduling disconnect"), this._schedulePendingDisconnect());
    }
    _schedulePendingDisconnect() {
      if (this._cancelPendingDisconnect(), this._disconnectOnEmptyChannelsAfterMs === 0) {
        this.log("transport", "disconnecting immediately - no channels"), this.disconnect();
        return;
      }
      this._pendingDisconnectTimer = setTimeout(() => {
        this._pendingDisconnectTimer = null, this.channels.length === 0 && (this.log("transport", "deferred disconnect fired - no channels, disconnecting"), this.disconnect());
      }, this._disconnectOnEmptyChannelsAfterMs), this.log("transport", "deferred disconnect scheduled in ".concat(this._disconnectOnEmptyChannelsAfterMs, "ms"));
    }
    _cancelPendingDisconnect() {
      this._pendingDisconnectTimer !== null && (this.log("transport", "pending disconnect cancelled - channel activity detected"), clearTimeout(this._pendingDisconnectTimer), this._pendingDisconnectTimer = null);
    }
    async _performAuth(t, e) {
      let r, s = false;
      if (t) r = t, s = true;
      else if (this.accessToken) try {
        r = await this.accessToken();
      } catch (n) {
        this.log("error", "Error fetching access token from callback", n), r = this.accessTokenValue;
      }
      else r = this.accessTokenValue;
      e === this._authGeneration && (this.accessToken ? this._manuallySetToken = false : s && (this._manuallySetToken = true), this.accessTokenValue != r && (this.accessTokenValue = r, this.channels.forEach((n) => {
        let i = { access_token: r, version: Ln };
        n.updateJoinPayload(i), n.joinedOnce && n.channelAdapter.isJoined() && n.channelAdapter.push(ls.access_token, { access_token: r });
      })));
    }
    async _waitForAuthIfNeeded() {
      this._authPromise && await this._authPromise;
    }
    _setAuthSafely(t = "general") {
      this._isManualToken() || this.setAuth().catch((e) => {
        this.log("error", "Error setting auth in ".concat(t), e);
      });
    }
    _setupConnectionHandlers() {
      this.socketAdapter.onOpen(() => {
        (this._authPromise || (this.accessToken && !this.accessTokenValue ? this.setAuth() : Promise.resolve())).catch((t) => {
          this.log("error", "error waiting for auth on connect", t);
        }), this.worker && !this.workerRef && this._startWorkerHeartbeat();
      }), this.socketAdapter.onClose(() => {
        this.worker && this.workerRef && this._terminateWorker();
      }), this.socketAdapter.onMessage((t) => {
        t.ref && t.ref === this._pendingWorkerHeartbeatRef && (this._pendingWorkerHeartbeatRef = null);
      });
    }
    _handleNodeJsRaceCondition() {
      this.socketAdapter.isConnected() && this.socketAdapter.getSocket().onConnOpen();
    }
    _wrapHeartbeatCallback(t) {
      return (e, r) => {
        e !== "disconnected" && (e == "sent" && this._setAuthSafely(), t && t(e, r));
      };
    }
    _startWorkerHeartbeat() {
      this.workerUrl ? this.log("worker", "starting worker for from ".concat(this.workerUrl)) : this.log("worker", "starting default worker");
      let t = this._workerObjectUrl(this.workerUrl);
      this.workerRef = new Worker(t), this.workerRef.onerror = (e) => {
        this.log("worker", "worker error", e.message), this._terminateWorker(), this.disconnect();
      }, this.workerRef.onmessage = (e) => {
        e.data.event === "keepAlive" && this.sendHeartbeat();
      }, this.workerRef.postMessage({ event: "start", interval: this.heartbeatIntervalMs });
    }
    _terminateWorker() {
      this.workerRef && (this.log("worker", "terminating worker"), this.workerRef.terminate(), this.workerRef = void 0);
    }
    _workerObjectUrl(t) {
      let e;
      if (t) e = t;
      else {
        let r = new Blob([Si], { type: "application/javascript" });
        e = URL.createObjectURL(r);
      }
      return e;
    }
    _initializeOptions(t) {
      var e, r, s, n, i, a, o, l, u, h, c, f;
      this.worker = (e = t == null ? void 0 : t.worker) !== null && e !== void 0 ? e : false, this.accessToken = (r = t == null ? void 0 : t.accessToken) !== null && r !== void 0 ? r : null;
      let d = {};
      d.timeout = (s = t == null ? void 0 : t.timeout) !== null && s !== void 0 ? s : Dn, d.heartbeatIntervalMs = (n = t == null ? void 0 : t.heartbeatIntervalMs) !== null && n !== void 0 ? n : Sr.HEARTBEAT_INTERVAL, this._disconnectOnEmptyChannelsAfterMs = (i = t == null ? void 0 : t.disconnectOnEmptyChannelsAfterMs) !== null && i !== void 0 ? i : 2 * ((a = t == null ? void 0 : t.heartbeatIntervalMs) !== null && a !== void 0 ? a : Sr.HEARTBEAT_INTERVAL), d.transport = (o = t == null ? void 0 : t.transport) !== null && o !== void 0 ? o : Nn.getWebSocketConstructor(), d.params = t == null ? void 0 : t.params, d.logger = t == null ? void 0 : t.logger, d.heartbeatCallback = this._wrapHeartbeatCallback(t == null ? void 0 : t.heartbeatCallback), d.sessionStorage = (l = t == null ? void 0 : t.sessionStorage) !== null && l !== void 0 ? l : Ei(), d.reconnectAfterMs = (u = t == null ? void 0 : t.reconnectAfterMs) !== null && u !== void 0 ? u : ((E) => vi[E - 1] || _i);
      let m, g, y = (h = t == null ? void 0 : t.vsn) !== null && h !== void 0 ? h : Bn;
      switch (y) {
        case Un:
          m = (E, k) => k(JSON.stringify(E)), g = (E, k) => k(JSON.parse(E));
          break;
        case os:
          m = this.serializer.encode.bind(this.serializer), g = this.serializer.decode.bind(this.serializer);
          break;
        default:
          throw new Error("Unsupported serializer version: ".concat(d.vsn));
      }
      if (d.vsn = y, d.encode = (c = t == null ? void 0 : t.encode) !== null && c !== void 0 ? c : m, d.decode = (f = t == null ? void 0 : t.decode) !== null && f !== void 0 ? f : g, d.beforeReconnect = this._reconnectAuth.bind(this), (t != null && t.logLevel || t != null && t.log_level) && (this.logLevel = t.logLevel || t.log_level, d.params = Object.assign(Object.assign({}, d.params), { log_level: this.logLevel })), this.worker) {
        if (typeof window != "undefined" && !window.Worker) throw new Error("Web Worker is not supported");
        this.workerUrl = t == null ? void 0 : t.workerUrl, d.autoSendHeartbeat = !this.worker;
      }
      return d;
    }
    async _reconnectAuth() {
      await this._waitForAuthIfNeeded(), this.isConnected() || this.connect();
    }
  };
  var Le = class extends Error {
    constructor(t, e) {
      var r;
      super(t), this.name = "IcebergError", this.status = e.status, this.icebergType = e.icebergType, this.icebergCode = e.icebergCode, this.details = e.details, this.isCommitStateUnknown = e.icebergType === "CommitStateUnknownException" || [500, 502, 504].includes(e.status) && ((r = e.icebergType) == null ? void 0 : r.includes("CommitState")) === true;
    }
    isNotFound() {
      return this.status === 404;
    }
    isConflict() {
      return this.status === 409;
    }
    isAuthenticationTimeout() {
      return this.status === 419;
    }
  };
  function Ri(t, e, r) {
    let s = new URL(e, t);
    if (r) for (let [n, i] of Object.entries(r)) i !== void 0 && s.searchParams.set(n, i);
    return s.toString();
  }
  async function Ai(t) {
    return !t || t.type === "none" ? {} : t.type === "bearer" ? { Authorization: "Bearer ".concat(t.token) } : t.type === "header" ? { [t.name]: t.value } : t.type === "custom" ? await t.getHeaders() : {};
  }
  function Oi(t) {
    var e;
    let r = (e = t.fetchImpl) != null ? e : globalThis.fetch;
    return { async request({ method: s, path: n, query: i, body: a, headers: o }) {
      var l;
      let u = Ri(t.baseUrl, n, i), h = await Ai(t.auth), c = await r(u, { method: s, headers: Tt(Tt(Tt({}, a ? { "Content-Type": "application/json" } : {}), h), o), body: a ? JSON.stringify(a) : void 0 }), f = await c.text(), d = (c.headers.get("content-type") || "").includes("application/json"), m = d && f ? JSON.parse(f) : f;
      if (!c.ok) {
        let g = d ? m : void 0, y = g == null ? void 0 : g.error;
        throw new Le((l = y == null ? void 0 : y.message) != null ? l : "Request failed with status ".concat(c.status), { status: c.status, icebergType: y == null ? void 0 : y.type, icebergCode: y == null ? void 0 : y.code, details: g });
      }
      return { status: c.status, headers: c.headers, data: m };
    } };
  }
  function Ve(t) {
    return t.join("");
  }
  var Ii = class {
    constructor(t, e = "") {
      this.client = t, this.prefix = e;
    }
    async listNamespaces(t) {
      let e = t ? { parent: Ve(t.namespace) } : void 0;
      return (await this.client.request({ method: "GET", path: "".concat(this.prefix, "/namespaces"), query: e })).data.namespaces.map((r) => ({ namespace: r }));
    }
    async createNamespace(t, e) {
      let r = { namespace: t.namespace, properties: e == null ? void 0 : e.properties };
      return (await this.client.request({ method: "POST", path: "".concat(this.prefix, "/namespaces"), body: r })).data;
    }
    async dropNamespace(t) {
      await this.client.request({ method: "DELETE", path: "".concat(this.prefix, "/namespaces/").concat(Ve(t.namespace)) });
    }
    async loadNamespaceMetadata(t) {
      return { properties: (await this.client.request({ method: "GET", path: "".concat(this.prefix, "/namespaces/").concat(Ve(t.namespace)) })).data.properties };
    }
    async namespaceExists(t) {
      try {
        return await this.client.request({ method: "HEAD", path: "".concat(this.prefix, "/namespaces/").concat(Ve(t.namespace)) }), true;
      } catch (e) {
        if (e instanceof Le && e.status === 404) return false;
        throw e;
      }
    }
    async createNamespaceIfNotExists(t, e) {
      try {
        return await this.createNamespace(t, e);
      } catch (r) {
        if (r instanceof Le && r.status === 409) return;
        throw r;
      }
    }
  };
  function me(t) {
    return t.join("");
  }
  var ji = class {
    constructor(t, e = "", r) {
      this.client = t, this.prefix = e, this.accessDelegation = r;
    }
    async listTables(t) {
      return (await this.client.request({ method: "GET", path: "".concat(this.prefix, "/namespaces/").concat(me(t.namespace), "/tables") })).data.identifiers;
    }
    async createTable(t, e) {
      let r = {};
      return this.accessDelegation && (r["X-Iceberg-Access-Delegation"] = this.accessDelegation), (await this.client.request({ method: "POST", path: "".concat(this.prefix, "/namespaces/").concat(me(t.namespace), "/tables"), body: e, headers: r })).data.metadata;
    }
    async updateTable(t, e) {
      let r = await this.client.request({ method: "POST", path: "".concat(this.prefix, "/namespaces/").concat(me(t.namespace), "/tables/").concat(t.name), body: e });
      return { "metadata-location": r.data["metadata-location"], metadata: r.data.metadata };
    }
    async dropTable(t, e) {
      var r;
      await this.client.request({ method: "DELETE", path: "".concat(this.prefix, "/namespaces/").concat(me(t.namespace), "/tables/").concat(t.name), query: { purgeRequested: String((r = e == null ? void 0 : e.purge) != null ? r : false) } });
    }
    async loadTable(t) {
      let e = {};
      return this.accessDelegation && (e["X-Iceberg-Access-Delegation"] = this.accessDelegation), (await this.client.request({ method: "GET", path: "".concat(this.prefix, "/namespaces/").concat(me(t.namespace), "/tables/").concat(t.name), headers: e })).data.metadata;
    }
    async tableExists(t) {
      let e = {};
      this.accessDelegation && (e["X-Iceberg-Access-Delegation"] = this.accessDelegation);
      try {
        return await this.client.request({ method: "HEAD", path: "".concat(this.prefix, "/namespaces/").concat(me(t.namespace), "/tables/").concat(t.name), headers: e }), true;
      } catch (r) {
        if (r instanceof Le && r.status === 404) return false;
        throw r;
      }
    }
    async createTableIfNotExists(t, e) {
      try {
        return await this.createTable(t, e);
      } catch (r) {
        if (r instanceof Le && r.status === 409) return await this.loadTable({ namespace: t.namespace, name: e.name });
        throw r;
      }
    }
  };
  var Pi = class {
    constructor(t) {
      var e;
      let r = "v1";
      t.catalogName && (r += "/".concat(t.catalogName));
      let s = t.baseUrl.endsWith("/") ? t.baseUrl : "".concat(t.baseUrl, "/");
      this.client = Oi({ baseUrl: s, auth: t.auth, fetchImpl: t.fetch }), this.accessDelegation = (e = t.accessDelegation) == null ? void 0 : e.join(","), this.namespaceOps = new Ii(this.client, r), this.tableOps = new ji(this.client, r, this.accessDelegation);
    }
    async listNamespaces(t) {
      return this.namespaceOps.listNamespaces(t);
    }
    async createNamespace(t, e) {
      return this.namespaceOps.createNamespace(t, e);
    }
    async dropNamespace(t) {
      await this.namespaceOps.dropNamespace(t);
    }
    async loadNamespaceMetadata(t) {
      return this.namespaceOps.loadNamespaceMetadata(t);
    }
    async listTables(t) {
      return this.tableOps.listTables(t);
    }
    async createTable(t, e) {
      return this.tableOps.createTable(t, e);
    }
    async updateTable(t, e) {
      return this.tableOps.updateTable(t, e);
    }
    async dropTable(t, e) {
      await this.tableOps.dropTable(t, e);
    }
    async loadTable(t) {
      return this.tableOps.loadTable(t);
    }
    async namespaceExists(t) {
      return this.namespaceOps.namespaceExists(t);
    }
    async tableExists(t) {
      return this.tableOps.tableExists(t);
    }
    async createNamespaceIfNotExists(t, e) {
      return this.namespaceOps.createNamespaceIfNotExists(t, e);
    }
    async createTableIfNotExists(t, e) {
      return this.tableOps.createTableIfNotExists(t, e);
    }
  };
  function Ue(t) {
    "@babel/helpers - typeof";
    return Ue = typeof Symbol == "function" && typeof Symbol.iterator == "symbol" ? function(e) {
      return typeof e;
    } : function(e) {
      return e && typeof Symbol == "function" && e.constructor === Symbol && e !== Symbol.prototype ? "symbol" : typeof e;
    }, Ue(t);
  }
  function Ci(t, e) {
    if (Ue(t) != "object" || !t) return t;
    var r = t[Symbol.toPrimitive];
    if (r !== void 0) {
      var s = r.call(t, e || "default");
      if (Ue(s) != "object") return s;
      throw new TypeError("@@toPrimitive must return a primitive value.");
    }
    return (e === "string" ? String : Number)(t);
  }
  function $i(t) {
    var e = Ci(t, "string");
    return Ue(e) == "symbol" ? e : e + "";
  }
  function Ni(t, e, r) {
    return (e = $i(e)) in t ? Object.defineProperty(t, e, { value: r, enumerable: true, configurable: true, writable: true }) : t[e] = r, t;
  }
  function Tr(t, e) {
    var r = Object.keys(t);
    if (Object.getOwnPropertySymbols) {
      var s = Object.getOwnPropertySymbols(t);
      e && (s = s.filter(function(n) {
        return Object.getOwnPropertyDescriptor(t, n).enumerable;
      })), r.push.apply(r, s);
    }
    return r;
  }
  function v(t) {
    for (var e = 1; e < arguments.length; e++) {
      var r = arguments[e] != null ? arguments[e] : {};
      e % 2 ? Tr(Object(r), true).forEach(function(s) {
        Ni(t, s, r[s]);
      }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(t, Object.getOwnPropertyDescriptors(r)) : Tr(Object(r)).forEach(function(s) {
        Object.defineProperty(t, s, Object.getOwnPropertyDescriptor(r, s));
      });
    }
    return t;
  }
  var pt = class extends Error {
    constructor(t, e = "storage", r, s) {
      super(t), this.__isStorageError = true, this.namespace = e, this.name = e === "vectors" ? "StorageVectorsError" : "StorageError", this.status = r, this.statusCode = s;
    }
    toJSON() {
      return { name: this.name, message: this.message, status: this.status, statusCode: this.statusCode };
    }
  };
  function gt(t) {
    return typeof t == "object" && t !== null && "__isStorageError" in t;
  }
  var Ut = class extends pt {
    constructor(t, e, r, s = "storage", n) {
      super(t, s, e, r), this.name = s === "vectors" ? "StorageVectorsApiError" : "StorageApiError", this.status = e, this.statusCode = r, this.code = n;
    }
    toJSON() {
      return v(v({}, super.toJSON()), {}, { code: this.code });
    }
  };
  var fs = class extends pt {
    constructor(t, e, r = "storage") {
      super(t, r), this.name = r === "vectors" ? "StorageVectorsUnknownError" : "StorageUnknownError", this.originalError = e;
    }
  };
  function it(t, e, r) {
    let s = v({}, t), n = e.toLowerCase();
    for (let i of Object.keys(s)) i.toLowerCase() === n && delete s[i];
    return s[n] = r, s;
  }
  function xi(t) {
    let e = {};
    for (let [r, s] of Object.entries(t)) e[r.toLowerCase()] = s;
    return e;
  }
  var Li = (t) => t ? (...e) => t(...e) : (...e) => fetch(...e);
  var Ui = (t) => {
    if (typeof t != "object" || t === null) return false;
    let e = Object.getPrototypeOf(t);
    return (e === null || e === Object.prototype || Object.getPrototypeOf(e) === null) && !(Symbol.toStringTag in t) && !(Symbol.iterator in t);
  };
  var Bt = (t) => {
    if (Array.isArray(t)) return t.map((r) => Bt(r));
    if (typeof t == "function" || t !== Object(t)) return t;
    let e = {};
    return Object.entries(t).forEach(([r, s]) => {
      let n = r.replace(/([-_][a-z])/gi, (i) => i.toUpperCase().replace(/[-_]/g, ""));
      e[n] = Bt(s);
    }), e;
  };
  var Bi = (t) => !t || typeof t != "string" || t.length === 0 || t.length > 100 || t.trim() !== t || t.includes("/") || t.includes("\\") ? false : /^[\w!.\*'() &$@=;:+,?-]+$/.test(t);
  var Dt = (t) => t.split("/").map(encodeURIComponent).join("/");
  var Rr = (t) => {
    if (typeof t == "object" && t !== null) {
      let e = t;
      if (typeof e.msg == "string") return e.msg;
      if (typeof e.message == "string") return e.message;
      if (typeof e.error_description == "string") return e.error_description;
      if (typeof e.error == "string") return e.error;
      if (typeof e.error == "object" && e.error !== null) {
        let r = e.error;
        if (typeof r.message == "string") return r.message;
      }
    }
    return JSON.stringify(t);
  };
  var Di = async (t, e, r, s) => {
    if (t !== null && typeof t == "object" && "json" in t && typeof t.json == "function") {
      let n = t, i = parseInt(String(n.status), 10);
      Number.isFinite(i) || (i = 500), n.json().then((a) => {
        let o = (a == null ? void 0 : a.statusCode) || (a == null ? void 0 : a.code) || i + "";
        e(new Ut(Rr(a), i, o, s, a == null ? void 0 : a.code));
      }).catch(() => {
        let a = i + "";
        e(new Ut(n.statusText || "HTTP ".concat(i, " error"), i, a, s));
      });
    } else e(new fs(Rr(t), t, s));
  };
  var qi = (t, e, r, s) => {
    let n = { method: t, headers: (e == null ? void 0 : e.headers) || {} };
    if (t === "GET" || t === "HEAD" || !s) return v(v({}, n), r);
    if (Ui(s)) {
      var i;
      let a = (e == null ? void 0 : e.headers) || {}, o;
      for (let [l, u] of Object.entries(a)) l.toLowerCase() === "content-type" && (o = u);
      n.headers = it(a, "Content-Type", (i = o) !== null && i !== void 0 ? i : "application/json"), n.body = JSON.stringify(s);
    } else n.body = s;
    return e != null && e.duplex && (n.duplex = e.duplex), v(v({}, n), r);
  };
  async function je(t, e, r, s, n, i, a) {
    return new Promise((o, l) => {
      t(r, qi(e, s, n, i)).then((u) => {
        if (!u.ok) throw u;
        if (s != null && s.noResolveJson) return u;
        if (a === "vectors") {
          let h = u.headers.get("content-type");
          if (u.headers.get("content-length") === "0" || u.status === 204) return {};
          if (!h || !h.includes("application/json")) return {};
        }
        return u.json();
      }).then((u) => o(u)).catch((u) => Di(u, l, s, a));
    });
  }
  function ps(t = "storage") {
    return { get: async (e, r, s, n) => je(e, "GET", r, s, n, void 0, t), post: async (e, r, s, n, i) => je(e, "POST", r, n, i, s, t), put: async (e, r, s, n, i) => je(e, "PUT", r, n, i, s, t), head: async (e, r, s, n) => je(e, "HEAD", r, v(v({}, s), {}, { noResolveJson: true }), n, void 0, t), remove: async (e, r, s, n, i) => je(e, "DELETE", r, n, i, s, t) };
  }
  var Mi = ps("storage");
  var { get: Se, post: F, put: at, head: Fi, remove: Te } = Mi;
  var B = ps("vectors");
  var Oe = class {
    constructor(t, e = {}, r, s = "storage") {
      this.shouldThrowOnError = false, this.url = t, this.headers = xi(e), this.fetch = Li(r), this.namespace = s;
    }
    throwOnError() {
      return this.shouldThrowOnError = true, this;
    }
    setHeader(t, e) {
      return this.headers = it(this.headers, t, e), this;
    }
    async handleOperation(t) {
      var e = this;
      try {
        return { data: await t(), error: null };
      } catch (r) {
        if (e.shouldThrowOnError) throw r;
        if (gt(r)) return { data: null, error: r };
        throw r;
      }
    }
  };
  var gs;
  gs = Symbol.toStringTag;
  var Hi = class {
    constructor(t, e) {
      this.downloadFn = t, this.shouldThrowOnError = e, this[gs] = "StreamDownloadBuilder", this.promise = null;
    }
    then(t, e) {
      return this.getPromise().then(t, e);
    }
    catch(t) {
      return this.getPromise().catch(t);
    }
    finally(t) {
      return this.getPromise().finally(t);
    }
    getPromise() {
      return this.promise || (this.promise = this.execute()), this.promise;
    }
    async execute() {
      var t = this;
      try {
        return { data: (await t.downloadFn()).body, error: null };
      } catch (e) {
        if (t.shouldThrowOnError) throw e;
        if (gt(e)) return { data: null, error: e };
        throw e;
      }
    }
  };
  var ys;
  ys = Symbol.toStringTag;
  var Wi = class {
    constructor(t, e) {
      this.downloadFn = t, this.shouldThrowOnError = e, this[ys] = "BlobDownloadBuilder", this.promise = null;
    }
    asStream() {
      return new Hi(this.downloadFn, this.shouldThrowOnError);
    }
    then(t, e) {
      return this.getPromise().then(t, e);
    }
    catch(t) {
      return this.getPromise().catch(t);
    }
    finally(t) {
      return this.getPromise().finally(t);
    }
    getPromise() {
      return this.promise || (this.promise = this.execute()), this.promise;
    }
    async execute() {
      var t = this;
      try {
        return { data: await (await t.downloadFn()).blob(), error: null };
      } catch (e) {
        if (t.shouldThrowOnError) throw e;
        if (gt(e)) return { data: null, error: e };
        throw e;
      }
    }
  };
  var Rt = { limit: 100, offset: 0, sortBy: { column: "name", order: "asc" } };
  var Ar = { cacheControl: "3600", contentType: "text/plain;charset=UTF-8", upsert: false };
  var Ki = class extends Oe {
    constructor(t, e = {}, r, s) {
      super(t, e, s, "storage"), this.bucketId = r;
    }
    async uploadOrUpdate(t, e, r, s) {
      var n = this;
      return n.handleOperation(async () => {
        let i, a = v(v({}, Ar), s), o = v(v({}, n.headers), t === "POST" && { "x-upsert": String(a.upsert) }), l = a.metadata;
        if (typeof Blob != "undefined" && r instanceof Blob || typeof FormData != "undefined" && r instanceof FormData ? i = n.prepareUploadFormData(r, a) : (i = r, o["cache-control"] = "max-age=".concat(a.cacheControl), o["content-type"] = a.contentType, a.contentEncoding && (o["content-encoding"] = a.contentEncoding), l && (o["x-metadata"] = n.toBase64(n.encodeMetadata(l))), (typeof ReadableStream != "undefined" && i instanceof ReadableStream || i && typeof i == "object" && "pipe" in i && typeof i.pipe == "function") && !a.duplex && (a.duplex = "half")), s != null && s.headers) for (let [f, d] of Object.entries(s.headers)) o = it(o, f, d);
        let u = n._removeEmptyFolders(e), h = n._getFinalPath(u), c = await (t == "PUT" ? at : F)(n.fetch, "".concat(n.url, "/object/").concat(h), i, v({ headers: o }, a != null && a.duplex ? { duplex: a.duplex } : {}));
        return { path: u, id: c.Id, fullPath: c.Key };
      });
    }
    async upload(t, e, r) {
      return this.uploadOrUpdate("POST", t, e, r);
    }
    async uploadToSignedUrl(t, e, r, s) {
      var n = this;
      let i = n._removeEmptyFolders(t), a = n._getFinalPath(i), o = new URL(n.url + "/object/upload/sign/".concat(a));
      return o.searchParams.set("token", e), n.handleOperation(async () => {
        let l, u = v(v({}, Ar), s), h = v(v({}, n.headers), { "x-upsert": String(u.upsert) }), c = u.metadata;
        if (typeof Blob != "undefined" && r instanceof Blob || typeof FormData != "undefined" && r instanceof FormData ? l = n.prepareUploadFormData(r, u) : (l = r, h["cache-control"] = "max-age=".concat(u.cacheControl), h["content-type"] = u.contentType, u.contentEncoding && (h["content-encoding"] = u.contentEncoding), c && (h["x-metadata"] = n.toBase64(n.encodeMetadata(c))), (typeof ReadableStream != "undefined" && l instanceof ReadableStream || l && typeof l == "object" && "pipe" in l && typeof l.pipe == "function") && !u.duplex && (u.duplex = "half")), s != null && s.headers) for (let [f, d] of Object.entries(s.headers)) h = it(h, f, d);
        return { path: i, fullPath: (await at(n.fetch, o.toString(), l, v({ headers: h }, u != null && u.duplex ? { duplex: u.duplex } : {}))).Key };
      });
    }
    async createSignedUploadUrl(t, e) {
      var r = this;
      return r.handleOperation(async () => {
        let s = r._getFinalPath(t), n = v({}, r.headers);
        e != null && e.upsert && (n["x-upsert"] = "true");
        let i = await F(r.fetch, "".concat(r.url, "/object/upload/sign/").concat(s), {}, { headers: n }), a = new URL(r.url + i.url), o = a.searchParams.get("token");
        if (!o) throw new pt("No token returned by API");
        return { signedUrl: a.toString(), path: t, token: o };
      });
    }
    async update(t, e, r) {
      return this.uploadOrUpdate("PUT", t, e, r);
    }
    async move(t, e, r) {
      var s = this;
      return s.handleOperation(async () => await F(s.fetch, "".concat(s.url, "/object/move"), { bucketId: s.bucketId, sourceKey: t, destinationKey: e, destinationBucket: r == null ? void 0 : r.destinationBucket, sourceVersionId: r == null ? void 0 : r.sourceVersionId }, { headers: s.headers }));
    }
    async copy(t, e, r) {
      var s = this;
      return s.handleOperation(async () => {
        let n = r;
        return { path: (await F(s.fetch, "".concat(s.url, "/object/copy"), { bucketId: s.bucketId, sourceKey: t, destinationKey: e, destinationBucket: r == null ? void 0 : r.destinationBucket, sourceVersionId: r == null ? void 0 : r.sourceVersionId, copyMetadata: typeof (n == null ? void 0 : n.copyMetadata) == "boolean" ? n.copyMetadata : void 0, metadata: (n == null ? void 0 : n.copyMetadata) === false ? n.metadata : void 0 }, { headers: s.headers })).Key };
      });
    }
    async createSignedUrl(t, e, r) {
      var s = this;
      return s.handleOperation(async () => {
        let n = s._getFinalPath(t), i = typeof (r == null ? void 0 : r.transform) == "object" && r.transform !== null && Object.keys(r.transform).length > 0, a = await F(s.fetch, "".concat(s.url, "/object/sign/").concat(n), v(v({ expiresIn: e }, i ? { transform: r.transform } : {}), (r == null ? void 0 : r.versionId) != null ? { versionId: r.versionId } : {}), { headers: s.headers }), o = new URLSearchParams();
        r != null && r.download && o.set("download", r.download === true ? "" : r.download), (r == null ? void 0 : r.cacheNonce) != null && o.set("cacheNonce", String(r.cacheNonce));
        let l = o.toString();
        return { signedUrl: encodeURI("".concat(s.url).concat(a.signedURL).concat(l ? "&".concat(l) : "")) };
      });
    }
    async createSignedUrls(t, e, r) {
      var s = this;
      return s.handleOperation(async () => {
        let n = await F(s.fetch, "".concat(s.url, "/object/sign/").concat(s.bucketId), { expiresIn: e, paths: t }, { headers: s.headers }), i = new URLSearchParams();
        r != null && r.download && i.set("download", r.download === true ? "" : r.download), (r == null ? void 0 : r.cacheNonce) != null && i.set("cacheNonce", String(r.cacheNonce));
        let a = i.toString();
        return n.map((o) => v(v({}, o), {}, { signedUrl: o.signedURL ? encodeURI("".concat(s.url).concat(o.signedURL).concat(a ? "&".concat(a) : "")) : null }));
      });
    }
    download(t, e, r) {
      let s = typeof (e == null ? void 0 : e.transform) == "object" && e.transform !== null && Object.keys(e.transform).length > 0 ? "render/image/authenticated" : "object", n = new URLSearchParams();
      e != null && e.transform && this.applyTransformOptsToQuery(n, e.transform), (e == null ? void 0 : e.cacheNonce) != null && n.set("cacheNonce", String(e.cacheNonce)), (e == null ? void 0 : e.versionId) != null && n.set("versionId", String(e.versionId));
      let i = n.toString(), a = this._getFinalPath(t), o = () => Se(this.fetch, "".concat(this.url, "/").concat(s, "/").concat(a).concat(i ? "?".concat(i) : ""), { headers: this.headers, noResolveJson: true }, r);
      return new Wi(o, this.shouldThrowOnError);
    }
    async info(t, e) {
      var r = this;
      let s = r._getFinalPath(t), n = new URLSearchParams();
      (e == null ? void 0 : e.versionId) != null && n.set("versionId", String(e.versionId));
      let i = n.toString();
      return r.handleOperation(async () => Bt(await Se(r.fetch, "".concat(r.url, "/object/info/").concat(s).concat(i ? "?".concat(i) : ""), { headers: r.headers })));
    }
    async exists(t) {
      var e = this;
      let r = e._getFinalPath(t);
      try {
        return await Fi(e.fetch, "".concat(e.url, "/object/").concat(r), { headers: e.headers }), { data: true, error: null };
      } catch (n) {
        if (e.shouldThrowOnError) throw n;
        if (gt(n)) {
          var s;
          let i = n instanceof Ut ? n.status : n instanceof fs ? (s = n.originalError) === null || s === void 0 ? void 0 : s.status : void 0;
          if (i !== void 0 && [400, 404].includes(i)) return { data: false, error: n };
        }
        throw n;
      }
    }
    getPublicUrl(t, e) {
      let r = this._getFinalPath(t), s = new URLSearchParams();
      e != null && e.download && s.set("download", e.download === true ? "" : e.download), e != null && e.transform && this.applyTransformOptsToQuery(s, e.transform), (e == null ? void 0 : e.cacheNonce) != null && s.set("cacheNonce", String(e.cacheNonce)), (e == null ? void 0 : e.versionId) != null && s.set("versionId", String(e.versionId));
      let n = s.toString(), i = typeof (e == null ? void 0 : e.transform) == "object" && e.transform !== null && Object.keys(e.transform).length > 0 ? "render/image" : "object";
      return { data: { publicUrl: encodeURI("".concat(this.url, "/").concat(i, "/public/").concat(r)) + (n ? "?".concat(n) : "") } };
    }
    async remove(t) {
      var e = this;
      return e.handleOperation(async () => await Te(e.fetch, "".concat(e.url, "/object/").concat(e.bucketId), { prefixes: t }, { headers: e.headers }));
    }
    async purgeCache(t, e, r) {
      var s = this;
      return s.handleOperation(async () => {
        let n = Dt(s._getFinalPath(t)), i = new URLSearchParams();
        e != null && e.transformations && i.set("transformations", "true");
        let a = i.toString();
        return await Te(s.fetch, "".concat(s.url, "/cdn/").concat(n).concat(a ? "?".concat(a) : ""), {}, { headers: s.headers }, r);
      });
    }
    async list(t, e, r) {
      var s = this;
      return s.handleOperation(async () => {
        let n = e != null && e.sortBy ? v(v({}, Rt.sortBy), e.sortBy) : Rt.sortBy, i = v(v(v({}, Rt), e), {}, { sortBy: n, prefix: t || "" });
        return await F(s.fetch, "".concat(s.url, "/object/list/").concat(s.bucketId), i, { headers: s.headers }, r);
      });
    }
    async listV2(t, e) {
      var r = this;
      return r.handleOperation(async () => {
        let s = v({}, t);
        return await F(r.fetch, "".concat(r.url, "/object/list-v2/").concat(r.bucketId), s, { headers: r.headers }, e);
      });
    }
    prepareUploadFormData(t, e) {
      let r = new FormData(), s = [];
      t instanceof FormData ? t.forEach((n, i) => {
        typeof n == "string" ? r.append(i, n) : s.push([i, n]);
      }) : s.push(["", t]), r.has("cacheControl") || r.append("cacheControl", e.cacheControl), e.metadata && !r.has("metadata") && r.append("metadata", this.encodeMetadata(e.metadata)), e.contentEncoding && !r.has("contentEncoding") && r.append("contentEncoding", e.contentEncoding);
      for (let [n, i] of s) r.append(n, i);
      return r;
    }
    encodeMetadata(t) {
      return JSON.stringify(t);
    }
    toBase64(t) {
      return typeof St != "undefined" ? St.from(t).toString("base64") : btoa(t);
    }
    _getFinalPath(t) {
      return "".concat(this.bucketId, "/").concat(t.replace(/^\/+/, ""));
    }
    _removeEmptyFolders(t) {
      return t.replace(/^\/|\/$/g, "").replace(/\/+/g, "/");
    }
    applyTransformOptsToQuery(t, e) {
      return e.width && t.set("width", e.width.toString()), e.height && t.set("height", e.height.toString()), e.resize && t.set("resize", e.resize), e.format && t.set("format", e.format), e.quality && t.set("quality", e.quality.toString()), t;
    }
  };
  var Gi = "2.118.0";
  var Fe = { "X-Client-Info": "storage-js/".concat(Gi) };
  var Ji = class extends Oe {
    constructor(t, e = {}, r, s) {
      let n = new URL(t);
      s != null && s.useNewHostname && /supabase\.(co|in|red)$/.test(n.hostname) && !n.hostname.includes("storage.supabase.") && (n.hostname = n.hostname.replace("supabase.", "storage.supabase."));
      let i = n.href.replace(/\/$/, ""), a = v(v({}, Fe), e);
      super(i, a, r, "storage");
    }
    async listBuckets(t) {
      var e = this;
      return e.handleOperation(async () => {
        let r = e.listBucketOptionsToQueryString(t);
        return await Se(e.fetch, "".concat(e.url, "/bucket").concat(r), { headers: e.headers });
      });
    }
    async getBucket(t) {
      var e = this;
      return e.handleOperation(async () => await Se(e.fetch, "".concat(e.url, "/bucket/").concat(t), { headers: e.headers }));
    }
    async createBucket(t, e = { public: false }) {
      var r = this;
      return r.handleOperation(async () => await F(r.fetch, "".concat(r.url, "/bucket"), { id: t, name: t, type: e.type, public: e.public, file_size_limit: e.fileSizeLimit, allowed_mime_types: e.allowedMimeTypes, versioning_status: e.versioningStatus }, { headers: r.headers }));
    }
    async updateBucket(t, e) {
      var r = this;
      return r.handleOperation(async () => await at(r.fetch, "".concat(r.url, "/bucket/").concat(t), { id: t, name: t, public: e.public, file_size_limit: e.fileSizeLimit, allowed_mime_types: e.allowedMimeTypes, versioning_status: e.versioningStatus }, { headers: r.headers }));
    }
    async emptyBucket(t) {
      var e = this;
      return e.handleOperation(async () => await F(e.fetch, "".concat(e.url, "/bucket/").concat(t, "/empty"), {}, { headers: e.headers }));
    }
    async deleteBucket(t) {
      var e = this;
      return e.handleOperation(async () => await Te(e.fetch, "".concat(e.url, "/bucket/").concat(t), {}, { headers: e.headers }));
    }
    async getBucketLifecycle(t) {
      var e = this;
      return e.handleOperation(async () => await Se(e.fetch, e.bucketLifecycleUrl(t), { headers: e.headers }));
    }
    async updateBucketLifecycle(t, e) {
      var r = this;
      return r.handleOperation(async () => await at(r.fetch, r.bucketLifecycleUrl(t), e, { headers: r.headers }));
    }
    async deleteBucketLifecycle(t) {
      var e = this;
      return e.handleOperation(async () => await Te(e.fetch, e.bucketLifecycleUrl(t), {}, { headers: e.headers }));
    }
    async purgeBucketCache(t, e, r) {
      var s = this;
      return s.handleOperation(async () => {
        let n = new URLSearchParams();
        e != null && e.transformations && n.set("transformations", "true");
        let i = n.toString();
        return await Te(s.fetch, "".concat(s.url, "/cdn/").concat(Dt(t)).concat(i ? "?".concat(i) : ""), {}, { headers: s.headers }, r);
      });
    }
    bucketLifecycleUrl(t) {
      return "".concat(this.url, "/bucket/").concat(Dt(t), "/lifecycle");
    }
    listBucketOptionsToQueryString(t) {
      let e = {};
      return t && ("limit" in t && (e.limit = String(t.limit)), "offset" in t && (e.offset = String(t.offset)), t.search && (e.search = t.search), t.sortColumn && (e.sortColumn = t.sortColumn), t.sortOrder && (e.sortOrder = t.sortOrder)), Object.keys(e).length > 0 ? "?" + new URLSearchParams(e).toString() : "";
    }
  };
  var Vi = class extends Oe {
    constructor(t, e = {}, r) {
      let s = t.replace(/\/$/, ""), n = v(v({}, Fe), e);
      super(s, n, r, "storage");
    }
    async createBucket(t) {
      var e = this;
      return e.handleOperation(async () => await F(e.fetch, "".concat(e.url, "/bucket"), { name: t }, { headers: e.headers }));
    }
    async listBuckets(t) {
      var e = this;
      return e.handleOperation(async () => {
        let r = new URLSearchParams();
        (t == null ? void 0 : t.limit) !== void 0 && r.set("limit", t.limit.toString()), (t == null ? void 0 : t.offset) !== void 0 && r.set("offset", t.offset.toString()), t != null && t.sortColumn && r.set("sortColumn", t.sortColumn), t != null && t.sortOrder && r.set("sortOrder", t.sortOrder), t != null && t.search && r.set("search", t.search);
        let s = r.toString(), n = s ? "".concat(e.url, "/bucket?").concat(s) : "".concat(e.url, "/bucket");
        return await Se(e.fetch, n, { headers: e.headers });
      });
    }
    async deleteBucket(t) {
      var e = this;
      return e.handleOperation(async () => await Te(e.fetch, "".concat(e.url, "/bucket/").concat(t), {}, { headers: e.headers }));
    }
    from(t) {
      var e = this;
      if (!Bi(t)) throw new pt("Invalid bucket name: File, folder, and bucket names must follow AWS object key naming guidelines and should avoid the use of any other characters.");
      let r = new Pi({ baseUrl: this.url, catalogName: t, auth: { type: "custom", getHeaders: async () => e.headers }, fetch: this.fetch }), s = this.shouldThrowOnError;
      return new Proxy(r, { get(n, i) {
        let a = n[i];
        return typeof a != "function" ? a : async (...o) => {
          try {
            return { data: await a.apply(n, o), error: null };
          } catch (l) {
            if (s) throw l;
            return { data: null, error: l };
          }
        };
      } });
    }
  };
  var zi = class extends Oe {
    constructor(t, e = {}, r) {
      let s = t.replace(/\/$/, ""), n = v(v({}, Fe), {}, { "Content-Type": "application/json" }, e);
      super(s, n, r, "vectors");
    }
    async createIndex(t) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/CreateIndex"), t, { headers: e.headers }) || {});
    }
    async getIndex(t, e) {
      var r = this;
      return r.handleOperation(async () => await B.post(r.fetch, "".concat(r.url, "/GetIndex"), { vectorBucketName: t, indexName: e }, { headers: r.headers }));
    }
    async listIndexes(t) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/ListIndexes"), t, { headers: e.headers }));
    }
    async deleteIndex(t, e) {
      var r = this;
      return r.handleOperation(async () => await B.post(r.fetch, "".concat(r.url, "/DeleteIndex"), { vectorBucketName: t, indexName: e }, { headers: r.headers }) || {});
    }
  };
  var Yi = class extends Oe {
    constructor(t, e = {}, r) {
      let s = t.replace(/\/$/, ""), n = v(v({}, Fe), {}, { "Content-Type": "application/json" }, e);
      super(s, n, r, "vectors");
    }
    async putVectors(t) {
      var e = this;
      if (t.vectors.length < 1 || t.vectors.length > 500) throw new Error("Vector batch size must be between 1 and 500 items");
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/PutVectors"), t, { headers: e.headers }) || {});
    }
    async getVectors(t) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/GetVectors"), t, { headers: e.headers }));
    }
    async listVectors(t) {
      var e = this;
      if (t.segmentCount !== void 0) {
        if (t.segmentCount < 1 || t.segmentCount > 16) throw new Error("segmentCount must be between 1 and 16");
        if (t.segmentIndex !== void 0 && (t.segmentIndex < 0 || t.segmentIndex >= t.segmentCount)) throw new Error("segmentIndex must be between 0 and ".concat(t.segmentCount - 1));
      }
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/ListVectors"), t, { headers: e.headers }));
    }
    async queryVectors(t) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/QueryVectors"), t, { headers: e.headers }));
    }
    async deleteVectors(t) {
      var e = this;
      if (t.keys.length < 1 || t.keys.length > 500) throw new Error("Keys batch size must be between 1 and 500 items");
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/DeleteVectors"), t, { headers: e.headers }) || {});
    }
  };
  var Xi = class extends Oe {
    constructor(t, e = {}, r) {
      let s = t.replace(/\/$/, ""), n = v(v({}, Fe), {}, { "Content-Type": "application/json" }, e);
      super(s, n, r, "vectors");
    }
    async createBucket(t) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/CreateVectorBucket"), { vectorBucketName: t }, { headers: e.headers }) || {});
    }
    async getBucket(t) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/GetVectorBucket"), { vectorBucketName: t }, { headers: e.headers }));
    }
    async listBuckets(t = {}) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/ListVectorBuckets"), t, { headers: e.headers }));
    }
    async deleteBucket(t) {
      var e = this;
      return e.handleOperation(async () => await B.post(e.fetch, "".concat(e.url, "/DeleteVectorBucket"), { vectorBucketName: t }, { headers: e.headers }) || {});
    }
  };
  var Qi = class extends Xi {
    constructor(t, e = {}) {
      super(t, e.headers || {}, e.fetch);
    }
    from(t) {
      return new Zi(this.url, this.headers, t, this.fetch);
    }
    async createBucket(t) {
      var e = () => super.createBucket, r = this;
      return e().call(r, t);
    }
    async getBucket(t) {
      var e = () => super.getBucket, r = this;
      return e().call(r, t);
    }
    async listBuckets(t = {}) {
      var e = () => super.listBuckets, r = this;
      return e().call(r, t);
    }
    async deleteBucket(t) {
      var e = () => super.deleteBucket, r = this;
      return e().call(r, t);
    }
  };
  var Zi = class extends zi {
    constructor(t, e, r, s) {
      super(t, e, s), this.vectorBucketName = r;
    }
    async createIndex(t) {
      var e = () => super.createIndex, r = this;
      return e().call(r, v(v({}, t), {}, { vectorBucketName: r.vectorBucketName }));
    }
    async listIndexes(t = {}) {
      var e = () => super.listIndexes, r = this;
      return e().call(r, v(v({}, t), {}, { vectorBucketName: r.vectorBucketName }));
    }
    async getIndex(t) {
      var e = () => super.getIndex, r = this;
      return e().call(r, r.vectorBucketName, t);
    }
    async deleteIndex(t) {
      var e = () => super.deleteIndex, r = this;
      return e().call(r, r.vectorBucketName, t);
    }
    index(t) {
      return new ea(this.url, this.headers, this.vectorBucketName, t, this.fetch);
    }
  };
  var ea = class extends Yi {
    constructor(t, e, r, s, n) {
      super(t, e, n), this.vectorBucketName = r, this.indexName = s;
    }
    async putVectors(t) {
      var e = () => super.putVectors, r = this;
      return e().call(r, v(v({}, t), {}, { vectorBucketName: r.vectorBucketName, indexName: r.indexName }));
    }
    async getVectors(t) {
      var e = () => super.getVectors, r = this;
      return e().call(r, v(v({}, t), {}, { vectorBucketName: r.vectorBucketName, indexName: r.indexName }));
    }
    async listVectors(t = {}) {
      var e = () => super.listVectors, r = this;
      return e().call(r, v(v({}, t), {}, { vectorBucketName: r.vectorBucketName, indexName: r.indexName }));
    }
    async queryVectors(t) {
      var e = () => super.queryVectors, r = this;
      return e().call(r, v(v({}, t), {}, { vectorBucketName: r.vectorBucketName, indexName: r.indexName }));
    }
    async deleteVectors(t) {
      var e = () => super.deleteVectors, r = this;
      return e().call(r, v(v({}, t), {}, { vectorBucketName: r.vectorBucketName, indexName: r.indexName }));
    }
  };
  var ta = class extends Ji {
    constructor(t, e = {}, r, s) {
      super(t, e, r, s);
    }
    from(t) {
      return new Ki(this.url, this.headers, t, this.fetch);
    }
    get vectors() {
      return new Qi(this.url + "/vector", { headers: this.headers, fetch: this.fetch });
    }
    get analytics() {
      return new Vi(this.url + "/iceberg", this.headers, this.fetch);
    }
  };
  var ms = "2.118.0";
  var te = 30 * 1e3;
  var $e = 3;
  var At = $e * te;
  var ra = 2 * te;
  var sa = "http://localhost:9999";
  var na = "supabase.auth.token";
  var ia = { "X-Client-Info": "gotrue-js/".concat(ms) };
  var qt = "X-Supabase-Api-Version";
  var ws = { "2024-01-01": { timestamp: Date.parse("2024-01-01T00:00:00.0Z"), name: "2024-01-01" } };
  var aa = /^([a-z0-9_-]{4})*($|[a-z0-9_-]{3}$|[a-z0-9_-]{2}$)$/i;
  var de = "sb_flow_id";
  var oa = 5;
  var la = 600 * 1e3;
  var Be = class extends Error {
    constructor(t, e, r) {
      super(t), this.__isAuthError = true, this.name = "AuthError", this.status = e, this.code = r;
    }
    toJSON() {
      return { name: this.name, message: this.message, status: this.status, code: this.code };
    }
  };
  function w(t) {
    return typeof t == "object" && t !== null && "__isAuthError" in t;
  }
  var ua = class extends Be {
    constructor(t, e, r) {
      super(t, e, r), this.name = "AuthApiError", this.status = e, this.code = r;
    }
  };
  function Or(t) {
    return w(t) && t.name === "AuthApiError";
  }
  var H = class extends Be {
    constructor(t, e) {
      super(t), this.name = "AuthUnknownError", this.originalError = e;
    }
  };
  var z = class extends Be {
    constructor(t, e, r, s) {
      super(t, r, s), this.name = e, this.status = r;
    }
  };
  var C = class extends z {
    constructor() {
      super("Auth session missing!", "AuthSessionMissingError", 400, void 0);
    }
  };
  function ze(t) {
    return w(t) && t.name === "AuthSessionMissingError";
  }
  var we = class extends z {
    constructor() {
      super("Auth session or user missing", "AuthInvalidTokenResponseError", 500, void 0);
    }
  };
  var Ye = class extends z {
    constructor(t) {
      super(t, "AuthInvalidCredentialsError", 400, void 0);
    }
  };
  var Xe = class extends z {
    constructor(t, e = null) {
      super(t, "AuthImplicitGrantRedirectError", 500, void 0), this.details = null, this.details = e;
    }
    toJSON() {
      return Object.assign(Object.assign({}, super.toJSON()), { details: this.details });
    }
  };
  function ha(t) {
    return w(t) && t.name === "AuthImplicitGrantRedirectError";
  }
  var Ir = class extends z {
    constructor(t, e = null) {
      super(t, "AuthPKCEGrantCodeExchangeError", 500, void 0), this.details = null, this.details = e;
    }
    toJSON() {
      return Object.assign(Object.assign({}, super.toJSON()), { details: this.details });
    }
  };
  var ca = class extends z {
    constructor() {
      super("PKCE code verifier not found in storage. This can happen if the auth flow was initiated in a different browser or device, or if the storage was cleared. For SSR frameworks (Next.js, SvelteKit, etc.), use @supabase/ssr on both the server and client to store the code verifier in cookies.", "AuthPKCECodeVerifierMissingError", 400, "pkce_code_verifier_not_found");
    }
  };
  var rt = class extends z {
    constructor(t, e) {
      super(t, "AuthRetryableFetchError", e, void 0);
    }
  };
  function Qe(t) {
    return w(t) && t.name === "AuthRetryableFetchError";
  }
  var jr = class extends z {
    constructor(t = "Refresh result discarded: session state changed mid-flight (e.g., concurrent signOut)") {
      super(t, "AuthRefreshDiscardedError", 409, void 0);
    }
  };
  function Pr(t) {
    return w(t) && t.name === "AuthRefreshDiscardedError";
  }
  var Cr = class extends z {
    constructor(t, e, r) {
      super(t, "AuthWeakPasswordError", e, "weak_password"), this.reasons = r;
    }
    toJSON() {
      return Object.assign(Object.assign({}, super.toJSON()), { reasons: this.reasons });
    }
  };
  var ot = class extends z {
    constructor(t) {
      super(t, "AuthInvalidJwtError", 400, "invalid_jwt");
    }
  };
  var lt = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".split("");
  var $r = " 	\n\r=".split("");
  var da = (() => {
    let t = new Array(128);
    for (let e = 0; e < t.length; e += 1) t[e] = -1;
    for (let e = 0; e < $r.length; e += 1) t[$r[e].charCodeAt(0)] = -2;
    for (let e = 0; e < lt.length; e += 1) t[lt[e].charCodeAt(0)] = e;
    return t;
  })();
  function Nr(t, e, r) {
    if (t !== null) for (e.queue = e.queue << 8 | t, e.queuedBits += 8; e.queuedBits >= 6; ) {
      let s = e.queue >> e.queuedBits - 6 & 63;
      r(lt[s]), e.queuedBits -= 6;
    }
    else if (e.queuedBits > 0) for (e.queue = e.queue << 6 - e.queuedBits, e.queuedBits = 6; e.queuedBits >= 6; ) {
      let s = e.queue >> e.queuedBits - 6 & 63;
      r(lt[s]), e.queuedBits -= 6;
    }
  }
  function bs(t, e, r) {
    let s = da[t];
    if (s > -1) for (e.queue = e.queue << 6 | s, e.queuedBits += 6; e.queuedBits >= 8; ) r(e.queue >> e.queuedBits - 8 & 255), e.queuedBits -= 8;
    else {
      if (s === -2) return;
      throw new Error('Invalid Base64-URL character "'.concat(String.fromCharCode(t), '"'));
    }
  }
  function xr(t) {
    let e = [], r = (a) => {
      e.push(String.fromCodePoint(a));
    }, s = { utf8seq: 0, codepoint: 0 }, n = { queue: 0, queuedBits: 0 }, i = (a) => {
      ga(a, s, r);
    };
    for (let a = 0; a < t.length; a += 1) bs(t.charCodeAt(a), n, i);
    return e.join("");
  }
  function fa(t, e) {
    if (t <= 127) {
      e(t);
      return;
    } else if (t <= 2047) {
      e(192 | t >> 6), e(128 | t & 63);
      return;
    } else if (t <= 65535) {
      e(224 | t >> 12), e(128 | t >> 6 & 63), e(128 | t & 63);
      return;
    } else if (t <= 1114111) {
      e(240 | t >> 18), e(128 | t >> 12 & 63), e(128 | t >> 6 & 63), e(128 | t & 63);
      return;
    }
    throw new Error("Unrecognized Unicode codepoint: ".concat(t.toString(16)));
  }
  function pa(t, e) {
    for (let r = 0; r < t.length; r += 1) {
      let s = t.charCodeAt(r);
      if (s > 55295 && s <= 56319) {
        let n = (s - 55296) * 1024 & 65535;
        s = (t.charCodeAt(r + 1) - 56320 & 65535 | n) + 65536, r += 1;
      }
      fa(s, e);
    }
  }
  function ga(t, e, r) {
    if (e.utf8seq === 0) {
      if (t <= 127) {
        r(t);
        return;
      }
      for (let s = 1; s < 6; s += 1) if ((t >> 7 - s & 1) === 0) {
        e.utf8seq = s;
        break;
      }
      if (e.utf8seq === 2) e.codepoint = t & 31;
      else if (e.utf8seq === 3) e.codepoint = t & 15;
      else if (e.utf8seq === 4) e.codepoint = t & 7;
      else throw new Error("Invalid UTF-8 sequence");
      e.utf8seq -= 1;
    } else if (e.utf8seq > 0) {
      if (t <= 127) throw new Error("Invalid UTF-8 sequence");
      e.codepoint = e.codepoint << 6 | t & 63, e.utf8seq -= 1, e.utf8seq === 0 && r(e.codepoint);
    }
  }
  function Re(t) {
    let e = [], r = { queue: 0, queuedBits: 0 }, s = (n) => {
      e.push(n);
    };
    for (let n = 0; n < t.length; n += 1) bs(t.charCodeAt(n), r, s);
    return new Uint8Array(e);
  }
  function ya(t) {
    let e = [];
    return pa(t, (r) => e.push(r)), new Uint8Array(e);
  }
  function fe(t) {
    let e = [], r = { queue: 0, queuedBits: 0 }, s = (n) => {
      e.push(n);
    };
    return t.forEach((n) => Nr(n, r, s)), Nr(null, r, s), e.join("");
  }
  function vs(t) {
    return Math.round(Date.now() / 1e3) + t;
  }
  function ma() {
    return Symbol("auth-callback");
  }
  var $ = () => typeof window != "undefined" && typeof document != "undefined";
  var le = { tested: false, writable: false };
  var _s = () => {
    if (!$()) return false;
    try {
      if (typeof globalThis.localStorage != "object") return false;
    } catch (e) {
      return false;
    }
    if (le.tested) return le.writable;
    let t = "lswt-".concat(Math.random()).concat(Math.random());
    try {
      globalThis.localStorage.setItem(t, t), globalThis.localStorage.removeItem(t), le.tested = true, le.writable = true;
    } catch (e) {
      le.tested = true, le.writable = false;
    }
    return le.writable;
  };
  function Lr(t) {
    let e = {}, r = new URL(t);
    if (r.hash && r.hash[0] === "#") try {
      new URLSearchParams(r.hash.substring(1)).forEach((s, n) => {
        e[n] = s;
      });
    } catch (s) {
    }
    return r.searchParams.forEach((s, n) => {
      e[n] = s;
    }), e;
  }
  var ks = (t) => t ? (...e) => t(...e) : (...e) => fetch(...e);
  var wa = (t) => typeof t == "object" && t !== null && "status" in t && "ok" in t && "json" in t && typeof t.json == "function";
  var se = async (t, e, r) => {
    await t.setItem(e, JSON.stringify(r));
  };
  var N = async (t, e) => {
    let r = await t.getItem(e);
    if (!r) return null;
    try {
      return JSON.parse(r);
    } catch (s) {
      return null;
    }
  };
  var U = async (t, e) => {
    await t.removeItem(e);
  };
  var Es = class Ss {
    constructor() {
      this.promise = new Ss.promiseConstructor((e, r) => {
        this.resolve = e, this.reject = r;
      });
    }
  };
  Es.promiseConstructor = Promise;
  function Ze(t) {
    let e = t.split(".");
    if (e.length !== 3) throw new ot("Invalid JWT structure");
    for (let r = 0; r < e.length; r++) if (!aa.test(e[r])) throw new ot("JWT not in base64url format");
    return { header: JSON.parse(xr(e[0])), payload: JSON.parse(xr(e[1])), signature: Re(e[2]), raw: { header: e[0], payload: e[1] } };
  }
  async function ba(t) {
    return await new Promise((e) => {
      setTimeout(() => e(null), t);
    });
  }
  function va(t, e) {
    return new Promise((r, s) => {
      (async () => {
        for (let n = 0; n < 1 / 0; n++) try {
          let i = await t(n);
          if (!e(n, null, i)) {
            r(i);
            return;
          }
        } catch (i) {
          if (!e(n, i)) {
            s(i);
            return;
          }
        }
      })();
    });
  }
  function Ts(t) {
    return ("0" + t.toString(16)).substr(-2);
  }
  function _a() {
    let t = new Uint32Array(56);
    if (typeof crypto == "undefined") {
      let e = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~", r = e.length, s = "";
      for (let n = 0; n < 56; n++) s += e.charAt(Math.floor(Math.random() * r));
      return s;
    }
    return crypto.getRandomValues(t), Array.from(t, Ts).join("");
  }
  async function ka(t) {
    let e = new TextEncoder().encode(t), r = await crypto.subtle.digest("SHA-256", e), s = new Uint8Array(r);
    return Array.from(s).map((n) => String.fromCharCode(n)).join("");
  }
  async function Ea(t) {
    if (!(typeof crypto != "undefined" && typeof crypto.subtle != "undefined" && typeof TextEncoder != "undefined")) return console.warn("WebCrypto API is not supported. Code challenge method will default to use plain instead of sha256."), t;
    let e = await ka(t);
    return btoa(e).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  var Sa = /^[a-zA-Z0-9_-]{8,64}$/;
  function st(t) {
    return typeof t == "string" && Sa.test(t) ? t : null;
  }
  function Ta() {
    if (typeof crypto != "undefined" && typeof crypto.getRandomValues == "function") {
      let e = new Uint8Array(16);
      return crypto.getRandomValues(e), Array.from(e, Ts).join("");
    }
    let t = "";
    for (let e = 0; e < 32; e++) t += Math.floor(Math.random() * 16).toString(16);
    return t;
  }
  var Ae = (t, e) => "".concat(t, "-flow-").concat(e, "-code-verifier");
  var De = (t) => "".concat(t, "-flows-code-verifier");
  async function Wt(t, e) {
    let r = await N(t, De(e));
    return Array.isArray(r) ? r.filter((s) => st(s) !== null) : [];
  }
  async function Ra(t, e, r, s, n) {
    await se(t, Ae(e, r), s);
    let i = (await Wt(t, e)).filter((a) => a !== r);
    for (i.push(r); i.length > oa; ) {
      let a = i.shift();
      await U(t, Ae(e, a)), n == null || n(a);
    }
    await se(t, De(e), i), await se(t, "".concat(e, "-code-verifier"), s);
  }
  async function Aa(t, e, r) {
    if (r) {
      let n = await N(t, Ae(e, r));
      return { verifier: typeof n == "string" ? n : null, flowId: r };
    }
    let s = await N(t, "".concat(e, "-code-verifier"));
    return { verifier: typeof s == "string" ? s : null, flowId: null };
  }
  async function M(t, e, r) {
    let s = "".concat(e, "-code-verifier");
    if (!r) {
      await U(t, s);
      return;
    }
    let n = Ae(e, r), i = await N(t, n);
    await U(t, n);
    let a = await Wt(t, e), o = a.filter((l) => l !== r);
    o.length !== a.length && (o.length > 0 ? await se(t, De(e), o) : await U(t, De(e))), i != null && i === await N(t, s) && await U(t, s);
  }
  async function Oa(t, e) {
    let r = await Wt(t, e);
    for (let s of r) await U(t, Ae(e, s));
    await U(t, De(e)), await U(t, "".concat(e, "-code-verifier"));
  }
  function Ia(t, e) {
    let r = t.indexOf("#"), s = r === -1 ? t : t.slice(0, r), n = r === -1 ? "" : t.slice(r), i = s.indexOf("?");
    if (i !== -1) {
      let o = s.slice(0, i), l = s.slice(i + 1).split("&").filter((u) => u !== "" && u !== de && !u.startsWith("".concat(de, "=")));
      s = l.length > 0 ? "".concat(o, "?").concat(l.join("&")) : o;
    }
    let a = s.includes("?") ? "&" : "?";
    return "".concat(s).concat(a).concat(de, "=").concat(encodeURIComponent(e)).concat(n);
  }
  async function ja(t, e, r = false, s) {
    let n = _a(), i = n;
    r && (i += "/recovery");
    let a = Ta();
    await Ra(t, e, a, i, s);
    let o = await Ea(n);
    return [o, n === o ? "plain" : "s256", a];
  }
  var Pa = /^2[0-9]{3}-(0[1-9]|1[0-2])-(0[1-9]|1[0-9]|2[0-9]|3[0-1])$/i;
  function Ca(t) {
    let e = t.headers.get(qt);
    if (!e || !e.match(Pa)) return null;
    try {
      return new Date("".concat(e, "T00:00:00.0Z"));
    } catch (r) {
      return null;
    }
  }
  function $a(t) {
    if (!t) throw new Error("Missing exp claim");
    let e = Math.floor(Date.now() / 1e3);
    if (t <= e) throw new Error("JWT has expired");
  }
  function Na(t) {
    switch (t) {
      case "RS256":
        return { name: "RSASSA-PKCS1-v1_5", hash: { name: "SHA-256" } };
      case "ES256":
        return { name: "ECDSA", namedCurve: "P-256", hash: { name: "SHA-256" } };
      default:
        throw new Error("Invalid alg claim");
    }
  }
  var xa = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  function Q(t) {
    if (!xa.test(t)) throw new Error("@supabase/auth-js: Expected parameter to be UUID but is not");
  }
  function Pe(t) {
    if (!t.recoveryCodes) throw new Error("@supabase/auth-js: the MFA recovery codes API is experimental and disabled by default. Enable it by passing `auth: { experimental: { recoveryCodes: true } }` to createClient (or to the GoTrueClient constructor).");
  }
  function Ot() {
    let t = {};
    return new Proxy(t, { get: (e, r) => {
      if (r === "__isUserNotAvailableProxy") return true;
      if (typeof r == "symbol") {
        let s = r.toString();
        if (s === "Symbol(Symbol.toPrimitive)" || s === "Symbol(Symbol.toStringTag)" || s === "Symbol(util.inspect.custom)") return;
      }
      throw new Error('@supabase/auth-js: client was created with userStorage option and there was no user stored in the user storage. Accessing the "'.concat(r, '" property of the session object is not supported. Please use getUser() instead.'));
    }, set: (e, r) => {
      throw new Error('@supabase/auth-js: client was created with userStorage option and there was no user stored in the user storage. Setting the "'.concat(r, '" property of the session object is not supported. Please use getUser() to fetch a user object you can manipulate.'));
    }, deleteProperty: (e, r) => {
      throw new Error('@supabase/auth-js: client was created with userStorage option and there was no user stored in the user storage. Deleting the "'.concat(r, '" property of the session object is not supported. Please use getUser() to fetch a user object you can manipulate.'));
    } });
  }
  function La(t, e) {
    return new Proxy(t, { get: (r, s, n) => {
      if (s === "__isInsecureUserWarningProxy") return true;
      if (typeof s == "symbol") {
        let i = s.toString();
        if (i === "Symbol(Symbol.toPrimitive)" || i === "Symbol(Symbol.toStringTag)" || i === "Symbol(util.inspect.custom)" || i === "Symbol(nodejs.util.inspect.custom)") return Reflect.get(r, s, n);
      }
      return !e.value && typeof s == "string" && (console.warn("Using the user object as returned from supabase.auth.getSession() or from some supabase.auth.onAuthStateChange() events could be insecure! This value comes directly from the storage medium (usually cookies on the server) and may not be authentic. Use supabase.auth.getUser() instead which authenticates the data by contacting the Supabase Auth server."), e.value = true), Reflect.get(r, s, n);
    } });
  }
  function Ur(t) {
    return JSON.parse(JSON.stringify(t));
  }
  var ue = (t) => {
    if (typeof t == "object" && t !== null) {
      let e = t;
      if (typeof e.msg == "string") return e.msg;
      if (typeof e.message == "string") return e.message;
      if (typeof e.error_description == "string") return e.error_description;
      if (typeof e.error == "string") return e.error;
    }
    return JSON.stringify(t);
  };
  var Br = [500, 501, 502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 527, 528, 529, 530];
  async function Dr(t) {
    var e;
    if (!wa(t)) throw new rt(ue(t), 0);
    let r;
    try {
      r = await t.json();
    } catch (i) {
      throw Br.includes(t.status) ? new rt(t.statusText || "HTTP ".concat(t.status), t.status) : new H(ue(i), i);
    }
    if (Br.includes(t.status)) throw new rt(ue(r), t.status);
    let s, n = Ca(t);
    if (n && n.getTime() >= ws["2024-01-01"].timestamp && typeof r == "object" && r && typeof r.code == "string" ? s = r.code : typeof r == "object" && r && typeof r.error_code == "string" && (s = r.error_code), s) {
      if (s === "weak_password") throw new Cr(ue(r), t.status, ((e = r.weak_password) === null || e === void 0 ? void 0 : e.reasons) || []);
      if (s === "session_not_found") throw new C();
    } else if (typeof r == "object" && r && typeof r.weak_password == "object" && r.weak_password && Array.isArray(r.weak_password.reasons) && r.weak_password.reasons.length && r.weak_password.reasons.reduce((i, a) => i && typeof a == "string", true)) throw new Cr(ue(r), t.status, r.weak_password.reasons);
    throw new ua(ue(r), t.status || 500, s);
  }
  var Ua = (t, e, r, s) => {
    let n = { method: t, headers: (e == null ? void 0 : e.headers) || {} };
    return t === "GET" ? n : (n.headers = Object.assign({ "Content-Type": "application/json;charset=UTF-8" }, e == null ? void 0 : e.headers), n.body = JSON.stringify(s), Object.assign(Object.assign({}, n), r));
  };
  async function b(t, e, r, s) {
    var n;
    let i = Object.assign({}, s == null ? void 0 : s.headers);
    i[qt] || (i[qt] = ws["2024-01-01"].name), s != null && s.jwt && (i.Authorization = "Bearer ".concat(s.jwt));
    let a = (n = s == null ? void 0 : s.query) !== null && n !== void 0 ? n : {};
    s != null && s.redirectTo && (a.redirect_to = s.redirectTo);
    let o = Object.keys(a).length ? "?" + new URLSearchParams(a).toString() : "", l = await Ba(t, e, r + o, { headers: i, noResolveJson: s == null ? void 0 : s.noResolveJson }, {}, s == null ? void 0 : s.body);
    return s != null && s.xform ? s == null ? void 0 : s.xform(l) : { data: Object.assign({}, l), error: null };
  }
  async function Ba(t, e, r, s, n, i) {
    let a = Ua(e, s, n, i), o;
    try {
      o = await t(r, Object.assign({}, a));
    } catch (l) {
      throw new rt(ue(l), 0);
    }
    if (o.ok || await Dr(o), s != null && s.noResolveJson) return o;
    try {
      return await o.json();
    } catch (l) {
      await Dr(l);
    }
  }
  function q(t) {
    var e;
    let r = null;
    Ma(t) && (r = Object.assign({}, t), t.expires_at || (r.expires_at = vs(t.expires_in)));
    let s = (e = t.user) !== null && e !== void 0 ? e : typeof (t == null ? void 0 : t.id) == "string" ? t : null;
    return { data: { session: r, user: s }, error: null };
  }
  function qr(t) {
    let e = q(t);
    return !e.error && t.weak_password && typeof t.weak_password == "object" && Array.isArray(t.weak_password.reasons) && t.weak_password.reasons.length && t.weak_password.message && typeof t.weak_password.message == "string" && t.weak_password.reasons.reduce((r, s) => r && typeof s == "string", true) && (e.data.weak_password = t.weak_password), e;
  }
  function ae(t) {
    var e;
    return { data: { user: (e = t.user) !== null && e !== void 0 ? e : t }, error: null };
  }
  function Da(t) {
    return { data: t, error: null };
  }
  function qa(t) {
    let { action_link: e, email_otp: r, hashed_token: s, redirect_to: n, verification_type: i } = t, a = ft(t, ["action_link", "email_otp", "hashed_token", "redirect_to", "verification_type"]), o = { action_link: e, email_otp: r, hashed_token: s, redirect_to: n, verification_type: i }, l = Object.assign({}, a);
    return { data: { properties: o, user: l }, error: null };
  }
  function Mr(t) {
    return t;
  }
  function Ma(t) {
    return !!t.access_token && !!t.refresh_token && !!t.expires_in;
  }
  var It = ["global", "local", "others"];
  var Rs = class {
    constructor({ url: t = "", headers: e = {}, fetch: r, experimental: s }) {
      this.url = t, this.headers = e, this.fetch = ks(r), this.experimental = s != null ? s : {}, this.mfa = { listFactors: this._listFactors.bind(this), deleteFactor: this._deleteFactor.bind(this) }, this.oauth = { listClients: this._listOAuthClients.bind(this), createClient: this._createOAuthClient.bind(this), getClient: this._getOAuthClient.bind(this), updateClient: this._updateOAuthClient.bind(this), deleteClient: this._deleteOAuthClient.bind(this), regenerateClientSecret: this._regenerateOAuthClientSecret.bind(this) }, this.customProviders = { listProviders: this._listCustomProviders.bind(this), createProvider: this._createCustomProvider.bind(this), getProvider: this._getCustomProvider.bind(this), updateProvider: this._updateCustomProvider.bind(this), deleteProvider: this._deleteCustomProvider.bind(this) }, this.passkey = { listPasskeys: this._adminListPasskeys.bind(this), deletePasskey: this._adminDeletePasskey.bind(this) };
    }
    async signOut(t, e = It[0]) {
      if (It.indexOf(e) < 0) throw new Error("@supabase/auth-js: Parameter scope must be one of ".concat(It.join(", ")));
      try {
        return await b(this.fetch, "POST", "".concat(this.url, "/logout?scope=").concat(e), { headers: this.headers, jwt: t, noResolveJson: true }), { data: null, error: null };
      } catch (r) {
        if (w(r)) return { data: null, error: r };
        throw r;
      }
    }
    async inviteUserByEmail(t, e = {}) {
      try {
        return await b(this.fetch, "POST", "".concat(this.url, "/invite"), { body: { email: t, data: e.data }, headers: this.headers, redirectTo: e.redirectTo, xform: ae });
      } catch (r) {
        if (w(r)) return { data: { user: null }, error: r };
        throw r;
      }
    }
    async generateLink(t) {
      try {
        let { options: e } = t, r = ft(t, ["options"]), s = Object.assign(Object.assign({}, r), e);
        return "newEmail" in r && (s.new_email = r == null ? void 0 : r.newEmail, delete s.newEmail), await b(this.fetch, "POST", "".concat(this.url, "/admin/generate_link"), { body: s, headers: this.headers, xform: qa, redirectTo: e == null ? void 0 : e.redirectTo });
      } catch (e) {
        if (w(e)) return { data: { properties: null, user: null }, error: e };
        throw e;
      }
    }
    async createUser(t) {
      try {
        return await b(this.fetch, "POST", "".concat(this.url, "/admin/users"), { body: t, headers: this.headers, xform: ae });
      } catch (e) {
        if (w(e)) return { data: { user: null }, error: e };
        throw e;
      }
    }
    async listUsers(t) {
      var e, r, s, n, i, a, o;
      try {
        let l = { nextPage: null, lastPage: 0, total: 0 }, u = await b(this.fetch, "GET", "".concat(this.url, "/admin/users"), { headers: this.headers, noResolveJson: true, query: { page: (r = (e = t == null ? void 0 : t.page) === null || e === void 0 ? void 0 : e.toString()) !== null && r !== void 0 ? r : "", per_page: (n = (s = t == null ? void 0 : t.perPage) === null || s === void 0 ? void 0 : s.toString()) !== null && n !== void 0 ? n : "" }, xform: Mr });
        if (u.error) throw u.error;
        let h = await u.json(), c = (i = u.headers.get("x-total-count")) !== null && i !== void 0 ? i : 0, f = (o = (a = u.headers.get("link")) === null || a === void 0 ? void 0 : a.split(",")) !== null && o !== void 0 ? o : [];
        return f.length > 0 && (f.forEach((d) => {
          let m = parseInt(d.split(";")[0].split("=")[1].substring(0, 1)), g = JSON.parse(d.split(";")[1].split("=")[1]);
          l["".concat(g, "Page")] = m;
        }), l.total = parseInt(c)), { data: Object.assign(Object.assign({}, h), l), error: null };
      } catch (l) {
        if (w(l)) return { data: { users: [] }, error: l };
        throw l;
      }
    }
    async getUserById(t) {
      Q(t);
      try {
        return await b(this.fetch, "GET", "".concat(this.url, "/admin/users/").concat(t), { headers: this.headers, xform: ae });
      } catch (e) {
        if (w(e)) return { data: { user: null }, error: e };
        throw e;
      }
    }
    async updateUserById(t, e) {
      Q(t);
      try {
        return await b(this.fetch, "PUT", "".concat(this.url, "/admin/users/").concat(t), { body: e, headers: this.headers, xform: ae });
      } catch (r) {
        if (w(r)) return { data: { user: null }, error: r };
        throw r;
      }
    }
    async deleteUser(t, e = false) {
      Q(t);
      try {
        return await b(this.fetch, "DELETE", "".concat(this.url, "/admin/users/").concat(t), { headers: this.headers, body: { should_soft_delete: e }, xform: ae });
      } catch (r) {
        if (w(r)) return { data: { user: null }, error: r };
        throw r;
      }
    }
    async _listFactors(t) {
      Q(t.userId);
      try {
        let { data: e, error: r } = await b(this.fetch, "GET", "".concat(this.url, "/admin/users/").concat(t.userId, "/factors"), { headers: this.headers, xform: (s) => ({ data: { factors: s }, error: null }) });
        return { data: e, error: r };
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _deleteFactor(t) {
      Q(t.userId), Q(t.id);
      try {
        return { data: await b(this.fetch, "DELETE", "".concat(this.url, "/admin/users/").concat(t.userId, "/factors/").concat(t.id), { headers: this.headers }), error: null };
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _listOAuthClients(t) {
      var e, r, s, n, i, a, o;
      try {
        let l = { nextPage: null, lastPage: 0, total: 0 }, u = await b(this.fetch, "GET", "".concat(this.url, "/admin/oauth/clients"), { headers: this.headers, noResolveJson: true, query: { page: (r = (e = t == null ? void 0 : t.page) === null || e === void 0 ? void 0 : e.toString()) !== null && r !== void 0 ? r : "", per_page: (n = (s = t == null ? void 0 : t.perPage) === null || s === void 0 ? void 0 : s.toString()) !== null && n !== void 0 ? n : "" }, xform: Mr });
        if (u.error) throw u.error;
        let h = await u.json(), c = (i = u.headers.get("x-total-count")) !== null && i !== void 0 ? i : 0, f = (o = (a = u.headers.get("link")) === null || a === void 0 ? void 0 : a.split(",")) !== null && o !== void 0 ? o : [];
        return f.length > 0 && (f.forEach((d) => {
          let m = parseInt(d.split(";")[0].split("=")[1].substring(0, 1)), g = JSON.parse(d.split(";")[1].split("=")[1]);
          l["".concat(g, "Page")] = m;
        }), l.total = parseInt(c)), { data: Object.assign(Object.assign({}, h), l), error: null };
      } catch (l) {
        if (w(l)) return { data: { clients: [] }, error: l };
        throw l;
      }
    }
    async _createOAuthClient(t) {
      try {
        return await b(this.fetch, "POST", "".concat(this.url, "/admin/oauth/clients"), { body: t, headers: this.headers, xform: (e) => ({ data: e, error: null }) });
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _getOAuthClient(t) {
      try {
        return await b(this.fetch, "GET", "".concat(this.url, "/admin/oauth/clients/").concat(t), { headers: this.headers, xform: (e) => ({ data: e, error: null }) });
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _updateOAuthClient(t, e) {
      try {
        return await b(this.fetch, "PUT", "".concat(this.url, "/admin/oauth/clients/").concat(t), { body: e, headers: this.headers, xform: (r) => ({ data: r, error: null }) });
      } catch (r) {
        if (w(r)) return { data: null, error: r };
        throw r;
      }
    }
    async _deleteOAuthClient(t) {
      try {
        return await b(this.fetch, "DELETE", "".concat(this.url, "/admin/oauth/clients/").concat(t), { headers: this.headers, noResolveJson: true }), { data: null, error: null };
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _regenerateOAuthClientSecret(t) {
      try {
        return await b(this.fetch, "POST", "".concat(this.url, "/admin/oauth/clients/").concat(t, "/regenerate_secret"), { headers: this.headers, xform: (e) => ({ data: e, error: null }) });
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _listCustomProviders(t) {
      try {
        let e = {};
        return t != null && t.type && (e.type = t.type), await b(this.fetch, "GET", "".concat(this.url, "/admin/custom-providers"), { headers: this.headers, query: e, xform: (r) => {
          var s;
          return { data: { providers: (s = r == null ? void 0 : r.providers) !== null && s !== void 0 ? s : [] }, error: null };
        } });
      } catch (e) {
        if (w(e)) return { data: { providers: [] }, error: e };
        throw e;
      }
    }
    async _createCustomProvider(t) {
      try {
        return await b(this.fetch, "POST", "".concat(this.url, "/admin/custom-providers"), { body: t, headers: this.headers, xform: (e) => ({ data: e, error: null }) });
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _getCustomProvider(t) {
      try {
        return await b(this.fetch, "GET", "".concat(this.url, "/admin/custom-providers/").concat(t), { headers: this.headers, xform: (e) => ({ data: e, error: null }) });
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _updateCustomProvider(t, e) {
      try {
        return await b(this.fetch, "PUT", "".concat(this.url, "/admin/custom-providers/").concat(t), { body: e, headers: this.headers, xform: (r) => ({ data: r, error: null }) });
      } catch (r) {
        if (w(r)) return { data: null, error: r };
        throw r;
      }
    }
    async _deleteCustomProvider(t) {
      try {
        return await b(this.fetch, "DELETE", "".concat(this.url, "/admin/custom-providers/").concat(t), { headers: this.headers, noResolveJson: true }), { data: null, error: null };
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _adminListPasskeys(t) {
      Q(t.userId);
      try {
        return await b(this.fetch, "GET", "".concat(this.url, "/admin/users/").concat(t.userId, "/passkeys"), { headers: this.headers, xform: (e) => ({ data: e, error: null }) });
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
    async _adminDeletePasskey(t) {
      Q(t.userId), Q(t.passkeyId);
      try {
        return await b(this.fetch, "DELETE", "".concat(this.url, "/admin/users/").concat(t.userId, "/passkeys/").concat(t.passkeyId), { headers: this.headers, noResolveJson: true }), { data: null, error: null };
      } catch (e) {
        if (w(e)) return { data: null, error: e };
        throw e;
      }
    }
  };
  function Fr(t = {}) {
    return { getItem: (e) => t[e] || null, setItem: (e, r) => {
      t[e] = r;
    }, removeItem: (e) => {
      delete t[e];
    } };
  }
  var G = { debug: !!(globalThis && _s() && globalThis.localStorage && globalThis.localStorage.getItem("supabase.gotrue-js.locks.debug") === "true") };
  var qe = class extends Error {
    constructor(t) {
      super(t), this.isAcquireTimeout = true;
    }
  };
  function Ha() {
    if (typeof globalThis != "object") try {
      Object.defineProperty(Object.prototype, "__magic__", { get: function() {
        return this;
      }, configurable: true }), __magic__.globalThis = __magic__, delete Object.prototype.__magic__;
    } catch (t) {
      typeof self != "undefined" && (self.globalThis = self);
    }
  }
  function As(t) {
    if (!/^0x[a-fA-F0-9]{40}$/.test(t)) throw new Error('@supabase/auth-js: Address "'.concat(t, '" is invalid.'));
    return t.toLowerCase();
  }
  function Wa(t) {
    return parseInt(t, 16);
  }
  function Ka(t) {
    let e = new TextEncoder().encode(t);
    return "0x" + Array.from(e, (r) => r.toString(16).padStart(2, "0")).join("");
  }
  function Ga(t) {
    var e;
    let { chainId: r, domain: s, expirationTime: n, issuedAt: i = /* @__PURE__ */ new Date(), nonce: a, notBefore: o, requestId: l, resources: u, scheme: h, uri: c, version: f } = t;
    {
      if (!Number.isInteger(r)) throw new Error('@supabase/auth-js: Invalid SIWE message field "chainId". Chain ID must be a EIP-155 chain ID. Provided value: '.concat(r));
      if (!s) throw new Error('@supabase/auth-js: Invalid SIWE message field "domain". Domain must be provided.');
      if (a && a.length < 8) throw new Error('@supabase/auth-js: Invalid SIWE message field "nonce". Nonce must be at least 8 characters. Provided value: '.concat(a));
      if (!c) throw new Error('@supabase/auth-js: Invalid SIWE message field "uri". URI must be provided.');
      if (f !== "1") throw new Error("@supabase/auth-js: Invalid SIWE message field \"version\". Version must be '1'. Provided value: ".concat(f));
      if (!((e = t.statement) === null || e === void 0) && e.includes("\n")) throw new Error("@supabase/auth-js: Invalid SIWE message field \"statement\". Statement must not include '\\n'. Provided value: ".concat(t.statement));
    }
    let d = As(t.address), m = h ? "".concat(h, "://").concat(s) : s, g = t.statement ? "".concat(t.statement, "\n") : "", y = "".concat(m, " wants you to sign in with your Ethereum account:\n").concat(d, "\n\n").concat(g), E = "URI: ".concat(c, "\nVersion: ").concat(f, "\nChain ID: ").concat(r).concat(a ? "\nNonce: ".concat(a) : "", "\nIssued At: ").concat(i.toISOString());
    if (n && (E += "\nExpiration Time: ".concat(n.toISOString())), o && (E += "\nNot Before: ".concat(o.toISOString())), l && (E += "\nRequest ID: ".concat(l)), u) {
      let k = "\nResources:";
      for (let _ of u) {
        if (!_ || typeof _ != "string") throw new Error('@supabase/auth-js: Invalid SIWE message field "resources". Every resource must be a valid string. Provided value: '.concat(_));
        k += "\n- ".concat(_);
      }
      E += k;
    }
    return "".concat(y, "\n").concat(E);
  }
  var I = class extends Error {
    constructor({ message: t, code: e, cause: r, name: s }) {
      var n;
      super(t, { cause: r }), this.__isWebAuthnError = true, this.name = (n = s != null ? s : r instanceof Error ? r.name : void 0) !== null && n !== void 0 ? n : "Unknown Error", this.code = e;
    }
    toJSON() {
      return { name: this.name, message: this.message, code: this.code };
    }
  };
  var ut = class extends I {
    constructor(t, e) {
      super({ code: "ERROR_PASSTHROUGH_SEE_CAUSE_PROPERTY", cause: e, message: t }), this.name = "WebAuthnUnknownError", this.originalError = e;
    }
  };
  function Ja({ error: t, options: e }) {
    var r, s, n;
    let { publicKey: i } = e;
    if (!i) throw Error("options was missing required publicKey property");
    if (t.name === "AbortError") {
      if (e.signal instanceof AbortSignal) return new I({ message: "Registration ceremony was sent an abort signal", code: "ERROR_CEREMONY_ABORTED", cause: t });
    } else if (t.name === "ConstraintError") {
      if (((r = i.authenticatorSelection) === null || r === void 0 ? void 0 : r.requireResidentKey) === true) return new I({ message: "Discoverable credentials were required but no available authenticator supported it", code: "ERROR_AUTHENTICATOR_MISSING_DISCOVERABLE_CREDENTIAL_SUPPORT", cause: t });
      if (e.mediation === "conditional" && ((s = i.authenticatorSelection) === null || s === void 0 ? void 0 : s.userVerification) === "required") return new I({ message: "User verification was required during automatic registration but it could not be performed", code: "ERROR_AUTO_REGISTER_USER_VERIFICATION_FAILURE", cause: t });
      if (((n = i.authenticatorSelection) === null || n === void 0 ? void 0 : n.userVerification) === "required") return new I({ message: "User verification was required but no available authenticator supported it", code: "ERROR_AUTHENTICATOR_MISSING_USER_VERIFICATION_SUPPORT", cause: t });
    } else {
      if (t.name === "InvalidStateError") return new I({ message: "The authenticator was previously registered", code: "ERROR_AUTHENTICATOR_PREVIOUSLY_REGISTERED", cause: t });
      if (t.name === "NotAllowedError") return new I({ message: t.message, code: "ERROR_PASSTHROUGH_SEE_CAUSE_PROPERTY", cause: t });
      if (t.name === "NotSupportedError") return i.pubKeyCredParams.filter((a) => a.type === "public-key").length === 0 ? new I({ message: 'No entry in pubKeyCredParams was of type "public-key"', code: "ERROR_MALFORMED_PUBKEYCREDPARAMS", cause: t }) : new I({ message: "No available authenticator supported any of the specified pubKeyCredParams algorithms", code: "ERROR_AUTHENTICATOR_NO_SUPPORTED_PUBKEYCREDPARAMS_ALG", cause: t });
      if (t.name === "SecurityError") {
        let a = window.location.hostname;
        if (Os(a)) {
          if (i.rp.id !== a) return new I({ message: 'The RP ID "'.concat(i.rp.id, '" is invalid for this domain'), code: "ERROR_INVALID_RP_ID", cause: t });
        } else return new I({ message: "".concat(window.location.hostname, " is an invalid domain"), code: "ERROR_INVALID_DOMAIN", cause: t });
      } else if (t.name === "TypeError") {
        if (i.user.id.byteLength < 1 || i.user.id.byteLength > 64) return new I({ message: "User ID was not between 1 and 64 characters", code: "ERROR_INVALID_USER_ID_LENGTH", cause: t });
      } else if (t.name === "UnknownError") return new I({ message: "The authenticator was unable to process the specified options, or could not create a new credential", code: "ERROR_AUTHENTICATOR_GENERAL_ERROR", cause: t });
    }
    return new I({ message: "a Non-Webauthn related error has occurred", code: "ERROR_PASSTHROUGH_SEE_CAUSE_PROPERTY", cause: t });
  }
  function Va({ error: t, options: e }) {
    let { publicKey: r } = e;
    if (!r) throw Error("options was missing required publicKey property");
    if (t.name === "AbortError") {
      if (e.signal instanceof AbortSignal) return new I({ message: "Authentication ceremony was sent an abort signal", code: "ERROR_CEREMONY_ABORTED", cause: t });
    } else {
      if (t.name === "NotAllowedError") return new I({ message: t.message, code: "ERROR_PASSTHROUGH_SEE_CAUSE_PROPERTY", cause: t });
      if (t.name === "SecurityError") {
        let s = window.location.hostname;
        if (Os(s)) {
          if (r.rpId !== s) return new I({ message: 'The RP ID "'.concat(r.rpId, '" is invalid for this domain'), code: "ERROR_INVALID_RP_ID", cause: t });
        } else return new I({ message: "".concat(window.location.hostname, " is an invalid domain"), code: "ERROR_INVALID_DOMAIN", cause: t });
      } else if (t.name === "UnknownError") return new I({ message: "The authenticator was unable to process the specified options, or could not create a new assertion signature", code: "ERROR_AUTHENTICATOR_GENERAL_ERROR", cause: t });
    }
    return new I({ message: "a Non-Webauthn related error has occurred", code: "ERROR_PASSTHROUGH_SEE_CAUSE_PROPERTY", cause: t });
  }
  var za = class {
    createNewAbortSignal() {
      if (this.controller) {
        let e = new Error("Cancelling existing WebAuthn API call for new one");
        e.name = "AbortError", this.controller.abort(e);
      }
      let t = new AbortController();
      return this.controller = t, t.signal;
    }
    cancelCeremony() {
      if (this.controller) {
        let t = new Error("Manually cancelling existing WebAuthn API call");
        t.name = "AbortError", this.controller.abort(t), this.controller = void 0;
      }
    }
  };
  var Mt = new za();
  function Kr(t) {
    if (!t) throw new Error("Credential creation options are required");
    if (typeof PublicKeyCredential != "undefined" && "parseCreationOptionsFromJSON" in PublicKeyCredential && typeof PublicKeyCredential.parseCreationOptionsFromJSON == "function") return PublicKeyCredential.parseCreationOptionsFromJSON(t);
    let { challenge: e, user: r, excludeCredentials: s } = t, n = ft(t, ["challenge", "user", "excludeCredentials"]), i = Re(e).buffer, a = Object.assign(Object.assign({}, r), { id: Re(r.id).buffer }), o = Object.assign(Object.assign({}, n), { challenge: i, user: a });
    if (s && s.length > 0) {
      o.excludeCredentials = new Array(s.length);
      for (let l = 0; l < s.length; l++) {
        let u = s[l];
        o.excludeCredentials[l] = Object.assign(Object.assign({}, u), { id: Re(u.id).buffer, type: u.type || "public-key", transports: u.transports });
      }
    }
    return o;
  }
  function Gr(t) {
    if (!t) throw new Error("Credential request options are required");
    if (typeof PublicKeyCredential != "undefined" && "parseRequestOptionsFromJSON" in PublicKeyCredential && typeof PublicKeyCredential.parseRequestOptionsFromJSON == "function") return PublicKeyCredential.parseRequestOptionsFromJSON(t);
    let { challenge: e, allowCredentials: r } = t, s = ft(t, ["challenge", "allowCredentials"]), n = Re(e).buffer, i = Object.assign(Object.assign({}, s), { challenge: n });
    if (r && r.length > 0) {
      i.allowCredentials = new Array(r.length);
      for (let a = 0; a < r.length; a++) {
        let o = r[a];
        i.allowCredentials[a] = Object.assign(Object.assign({}, o), { id: Re(o.id).buffer, type: o.type || "public-key", transports: o.transports });
      }
    }
    return i;
  }
  function Jr(t) {
    var e;
    if ("toJSON" in t && typeof t.toJSON == "function") return t.toJSON();
    let r = t;
    return { id: t.id, rawId: t.id, response: { attestationObject: fe(new Uint8Array(t.response.attestationObject)), clientDataJSON: fe(new Uint8Array(t.response.clientDataJSON)) }, type: "public-key", clientExtensionResults: t.getClientExtensionResults(), authenticatorAttachment: (e = r.authenticatorAttachment) !== null && e !== void 0 ? e : void 0 };
  }
  function Vr(t) {
    var e;
    if ("toJSON" in t && typeof t.toJSON == "function") return t.toJSON();
    let r = t, s = t.getClientExtensionResults(), n = t.response;
    return { id: t.id, rawId: t.id, response: { authenticatorData: fe(new Uint8Array(n.authenticatorData)), clientDataJSON: fe(new Uint8Array(n.clientDataJSON)), signature: fe(new Uint8Array(n.signature)), userHandle: n.userHandle ? fe(new Uint8Array(n.userHandle)) : void 0 }, type: "public-key", clientExtensionResults: s, authenticatorAttachment: (e = r.authenticatorAttachment) !== null && e !== void 0 ? e : void 0 };
  }
  function Os(t) {
    return t === "localhost" || /^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/i.test(t);
  }
  function ht() {
    var t, e;
    return !!($() && "PublicKeyCredential" in window && window.PublicKeyCredential && "credentials" in navigator && typeof ((t = navigator == null ? void 0 : navigator.credentials) === null || t === void 0 ? void 0 : t.create) == "function" && typeof ((e = navigator == null ? void 0 : navigator.credentials) === null || e === void 0 ? void 0 : e.get) == "function");
  }
  async function Is(t) {
    try {
      let e = await navigator.credentials.create(t);
      return e ? e instanceof PublicKeyCredential ? { data: e, error: null } : { data: null, error: new ut("Browser returned unexpected credential type", e) } : { data: null, error: new ut("Empty credential response", e) };
    } catch (e) {
      return { data: null, error: Ja({ error: e, options: t }) };
    }
  }
  async function js(t) {
    try {
      let e = await navigator.credentials.get(t);
      return e ? e instanceof PublicKeyCredential ? { data: e, error: null } : { data: null, error: new ut("Browser returned unexpected credential type", e) } : { data: null, error: new ut("Empty credential response", e) };
    } catch (e) {
      return { data: null, error: Va({ error: e, options: t }) };
    }
  }
  var Ya = { hints: ["security-key"], authenticatorSelection: { authenticatorAttachment: "cross-platform", requireResidentKey: false, userVerification: "preferred", residentKey: "discouraged" }, attestation: "direct" };
  var Xa = { userVerification: "preferred", hints: ["security-key"], attestation: "direct" };
  function ct(...t) {
    let e = (n) => n !== null && typeof n == "object" && !Array.isArray(n), r = (n) => n instanceof ArrayBuffer || ArrayBuffer.isView(n), s = {};
    for (let n of t) if (n) for (let i in n) {
      let a = n[i];
      if (a !== void 0) if (Array.isArray(a)) s[i] = a;
      else if (r(a)) s[i] = a;
      else if (e(a)) {
        let o = s[i];
        e(o) ? s[i] = ct(o, a) : s[i] = ct(a);
      } else s[i] = a;
    }
    return s;
  }
  function Qa(t, e) {
    return ct(Ya, t, e || {});
  }
  function Za(t, e) {
    return ct(Xa, t, e || {});
  }
  var eo = class {
    constructor(t) {
      this.client = t, this.enroll = this._enroll.bind(this), this.challenge = this._challenge.bind(this), this.verify = this._verify.bind(this), this.authenticate = this._authenticate.bind(this), this.register = this._register.bind(this);
    }
    async _enroll(t) {
      return this.client.mfa.enroll(Object.assign(Object.assign({}, t), { factorType: "webauthn" }));
    }
    async _challenge({ factorId: t, webauthn: e, friendlyName: r, signal: s }, n) {
      var i;
      try {
        let { data: a, error: o } = await this.client.mfa.challenge({ factorId: t, webauthn: e });
        if (!a) return { data: null, error: o };
        let l = s != null ? s : Mt.createNewAbortSignal();
        if (a.webauthn.type === "create") {
          let { user: u } = a.webauthn.credential_options.publicKey;
          if (!u.name) {
            let h = r;
            if (h) u.name = "".concat(u.id, ":").concat(h);
            else {
              let c = (await this.client.getUser()).data.user, f = ((i = c == null ? void 0 : c.user_metadata) === null || i === void 0 ? void 0 : i.name) || (c == null ? void 0 : c.email) || (c == null ? void 0 : c.id) || "User";
              u.name = "".concat(u.id, ":").concat(f);
            }
          }
          u.displayName || (u.displayName = u.name);
        }
        switch (a.webauthn.type) {
          case "create": {
            let u = Qa(a.webauthn.credential_options.publicKey, n == null ? void 0 : n.create), { data: h, error: c } = await Is({ publicKey: u, signal: l });
            return h ? { data: { factorId: t, challengeId: a.id, webauthn: { type: a.webauthn.type, credential_response: h } }, error: null } : { data: null, error: c };
          }
          case "request": {
            let u = Za(a.webauthn.credential_options.publicKey, n == null ? void 0 : n.request), { data: h, error: c } = await js(Object.assign(Object.assign({}, a.webauthn.credential_options), { publicKey: u, signal: l }));
            return h ? { data: { factorId: t, challengeId: a.id, webauthn: { type: a.webauthn.type, credential_response: h } }, error: null } : { data: null, error: c };
          }
        }
      } catch (a) {
        return w(a) ? { data: null, error: a } : { data: null, error: new H("Unexpected error in challenge", a) };
      }
    }
    async _verify({ challengeId: t, factorId: e, webauthn: r }) {
      return this.client.mfa.verify({ factorId: e, challengeId: t, webauthn: r });
    }
    async _authenticate({ factorId: t, webauthn: { rpId: e = typeof window != "undefined" ? window.location.hostname : void 0, rpOrigins: r = typeof window != "undefined" ? [window.location.origin] : void 0, signal: s } = {} }, n) {
      if (!e) return { data: null, error: new Be("rpId is required for WebAuthn authentication") };
      try {
        if (!ht()) return { data: null, error: new H("Browser does not support WebAuthn", null) };
        let { data: i, error: a } = await this.challenge({ factorId: t, webauthn: { rpId: e, rpOrigins: r }, signal: s }, { request: n });
        if (!i) return { data: null, error: a };
        let { webauthn: o } = i;
        return this._verify({ factorId: t, challengeId: i.challengeId, webauthn: { type: o.type, rpId: e, rpOrigins: r, credential_response: o.credential_response } });
      } catch (i) {
        return w(i) ? { data: null, error: i } : { data: null, error: new H("Unexpected error in authenticate", i) };
      }
    }
    async _register({ friendlyName: t, webauthn: { rpId: e = typeof window != "undefined" ? window.location.hostname : void 0, rpOrigins: r = typeof window != "undefined" ? [window.location.origin] : void 0, signal: s } = {} }, n) {
      if (!e) return { data: null, error: new Be("rpId is required for WebAuthn registration") };
      try {
        if (!ht()) return { data: null, error: new H("Browser does not support WebAuthn", null) };
        let { data: i, error: a } = await this._enroll({ friendlyName: t });
        if (!i) return await this.client.mfa.listFactors().then((u) => {
          var h;
          return (h = u.data) === null || h === void 0 ? void 0 : h.all.find((c) => c.factor_type === "webauthn" && c.friendly_name === t && c.status === "unverified");
        }).then((u) => u ? this.client.mfa.unenroll({ factorId: u == null ? void 0 : u.id }) : void 0), { data: null, error: a };
        let { data: o, error: l } = await this._challenge({ factorId: i.id, friendlyName: i.friendly_name, webauthn: { rpId: e, rpOrigins: r }, signal: s }, { create: n });
        return o ? this._verify({ factorId: i.id, challengeId: o.challengeId, webauthn: { rpId: e, rpOrigins: r, type: o.webauthn.type, credential_response: o.webauthn.credential_response } }) : { data: null, error: l };
      } catch (i) {
        return w(i) ? { data: null, error: i } : { data: null, error: new H("Unexpected error in register", i) };
      }
    }
  };
  Ha();
  var to = { url: sa, storageKey: na, autoRefreshToken: true, persistSession: true, detectSessionInUrl: true, headers: ia, flowType: "implicit", debug: false, hasCustomAuthorizationHeader: false, throwOnError: false, lockAcquireTimeout: 5e3, skipAutoInitialize: false, experimental: {} };
  var be = {};
  var zr = false;
  var Ps = class Ft {
    get jwks() {
      var e, r;
      return (r = (e = be[this.storageKey]) === null || e === void 0 ? void 0 : e.jwks) !== null && r !== void 0 ? r : { keys: [] };
    }
    set jwks(e) {
      be[this.storageKey] = Object.assign(Object.assign({}, be[this.storageKey]), { jwks: e });
    }
    get jwks_cached_at() {
      var e, r;
      return (r = (e = be[this.storageKey]) === null || e === void 0 ? void 0 : e.cachedAt) !== null && r !== void 0 ? r : Number.MIN_SAFE_INTEGER;
    }
    set jwks_cached_at(e) {
      be[this.storageKey] = Object.assign(Object.assign({}, be[this.storageKey]), { cachedAt: e });
    }
    constructor(e) {
      var r, s, n;
      this.userStorage = null, this.memoryStorage = null, this.stateChangeEmitters = /* @__PURE__ */ new Map(), this.autoRefreshTicker = null, this.autoRefreshTickTimeout = null, this.visibilityChangedCallback = null, this.refreshingDeferred = null, this.lastRefreshFailure = null, this._sessionRemovalEpoch = 0, this.initializePromise = null, this._pendingInitNotifications = null, this.detectSessionInUrl = true, this.hasCustomAuthorizationHeader = false, this.suppressGetSessionWarning = false, this.lock = null, this.lockAcquired = false, this.pendingInLock = [], this.broadcastChannel = null, this.logger = console.log;
      let i = Object.assign(Object.assign({}, to), e);
      if (this.storageKey = i.storageKey, this.instanceID = (r = Ft.nextInstanceID[this.storageKey]) !== null && r !== void 0 ? r : 0, Ft.nextInstanceID[this.storageKey] = this.instanceID + 1, this.logDebugMessages = !!i.debug, typeof i.debug == "function" && (this.logger = i.debug), this.instanceID > 0 && $()) {
        let a = "".concat(this._logPrefix(), " Multiple GoTrueClient instances detected in the same browser context. It is not an error, but this should be avoided as it may produce undefined behavior when used concurrently under the same storage key.");
        console.warn(a), this.logDebugMessages && console.trace(a);
      }
      if (this.persistSession = i.persistSession, this.autoRefreshToken = i.autoRefreshToken, this.experimental = (s = i.experimental) !== null && s !== void 0 ? s : {}, this.admin = new Rs({ url: i.url, headers: i.headers, fetch: i.fetch, experimental: this.experimental }), this.url = i.url, this.headers = i.headers, this.fetch = ks(i.fetch), this.detectSessionInUrl = i.detectSessionInUrl, this.flowType = i.flowType, this.hasCustomAuthorizationHeader = i.hasCustomAuthorizationHeader, this.throwOnError = i.throwOnError, this.lockAcquireTimeout = i.lockAcquireTimeout, i.lock != null && (this.lock = i.lock, zr || (zr = true, console.warn("".concat(this._logPrefix(), ' The "lock" option is deprecated and will be removed in v3. The client now coordinates session refreshes without a lock, so most apps can drop the option. See https://github.com/supabase/supabase-js/blob/master/packages/core/auth-js/migrations/lockless-coordination.md')))), this.jwks || (this.jwks = { keys: [] }, this.jwks_cached_at = Number.MIN_SAFE_INTEGER), this.mfa = { verify: this._verify.bind(this), enroll: this._enroll.bind(this), unenroll: this._unenroll.bind(this), challenge: this._challenge.bind(this), listFactors: this._listFactors.bind(this), challengeAndVerify: this._challengeAndVerify.bind(this), getAuthenticatorAssuranceLevel: this._getAuthenticatorAssuranceLevel.bind(this), webauthn: new eo(this), recoveryCodes: { getStatus: this._getRecoveryCodesStatus.bind(this), generate: this._generateRecoveryCodes.bind(this), verify: this._verifyRecoveryCode.bind(this), regenerate: this._regenerateRecoveryCodes.bind(this), unenroll: this._unenrollRecoveryCodes.bind(this) } }, this.oauth = { getAuthorizationDetails: this._getAuthorizationDetails.bind(this), approveAuthorization: this._approveAuthorization.bind(this), denyAuthorization: this._denyAuthorization.bind(this), listGrants: this._listOAuthGrants.bind(this), revokeGrant: this._revokeOAuthGrant.bind(this) }, this.passkey = { startRegistration: this._startPasskeyRegistration.bind(this), verifyRegistration: this._verifyPasskeyRegistration.bind(this), startAuthentication: this._startPasskeyAuthentication.bind(this), verifyAuthentication: this._verifyPasskeyAuthentication.bind(this), list: this._listPasskeys.bind(this), update: this._updatePasskey.bind(this), delete: this._deletePasskey.bind(this) }, this.persistSession ? (i.storage ? this.storage = i.storage : _s() ? this.storage = globalThis.localStorage : (this.memoryStorage = {}, this.storage = Fr(this.memoryStorage)), i.userStorage && (this.userStorage = i.userStorage)) : (this.memoryStorage = {}, this.storage = Fr(this.memoryStorage)), $() && globalThis.BroadcastChannel && this.persistSession && this.storageKey) {
        try {
          this.broadcastChannel = new globalThis.BroadcastChannel(this.storageKey);
        } catch (a) {
          console.error("Failed to create a new BroadcastChannel, multi-tab state changes will not be available", a);
        }
        (n = this.broadcastChannel) === null || n === void 0 || n.addEventListener("message", async (a) => {
          this._debug("received broadcast notification from other tab or client", a), (a.data.event === "TOKEN_REFRESHED" || a.data.event === "SIGNED_IN") && (this.lastRefreshFailure = null);
          try {
            await this._notifyAllSubscribers(a.data.event, a.data.session, false);
          } catch (o) {
            this._debug("#broadcastChannel", "error", o);
          }
        });
      }
      i.skipAutoInitialize || this.initialize().catch((a) => {
        this._debug("#initialize()", "error", a);
      });
    }
    isThrowOnErrorEnabled() {
      return this.throwOnError;
    }
    _returnResult(e) {
      if (this.throwOnError && e && e.error) throw e.error;
      return e;
    }
    _logPrefix() {
      return "GoTrueClient@".concat(this.storageKey, ":").concat(this.instanceID, " (").concat(ms, ") ").concat((/* @__PURE__ */ new Date()).toISOString());
    }
    _debug(...e) {
      return this.logDebugMessages && this.logger(this._logPrefix(), ...e), this;
    }
    async initialize() {
      var e;
      if (this.initializePromise) return await this.initializePromise;
      this._pendingInitNotifications = [], this.initializePromise = (async () => this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => await this._initialize()) : await this._initialize())();
      let r = await this.initializePromise, s = (e = this._pendingInitNotifications) !== null && e !== void 0 ? e : [];
      this._pendingInitNotifications = null;
      for (let n of s) await this._notifyAllSubscribers(n.event, n.session, n.broadcast);
      return r;
    }
    async _initialize() {
      var e;
      try {
        let r = {}, s = "none";
        if ($() && (r = Lr(window.location.href), this._isImplicitGrantCallback(r) ? s = "implicit" : await this._isPKCECallback(r) && (s = "pkce")), $() && this.detectSessionInUrl && s !== "none") {
          let { data: n, error: i } = await this._getSessionFromURL(r, s);
          if (i) {
            if (this._debug("#_initialize()", "error detecting session from URL", i), ha(i)) {
              let l = (e = i.details) === null || e === void 0 ? void 0 : e.code;
              if (l === "identity_already_exists" || l === "identity_not_found" || l === "single_identity_not_deletable") return { error: i };
            }
            return { error: i };
          }
          let { session: a, redirectType: o } = n;
          return this._debug("#_initialize()", "detected session in URL", a, "redirect type", o), await this._saveSession(a), setTimeout(async () => {
            o === "recovery" ? await this._notifyAllSubscribers("PASSWORD_RECOVERY", a) : await this._notifyAllSubscribers("SIGNED_IN", a);
          }, 0), { error: null };
        }
        return await this._recoverAndRefresh(), { error: null };
      } catch (r) {
        return w(r) ? this._returnResult({ error: r }) : this._returnResult({ error: new H("Unexpected error during initialization", r) });
      } finally {
        await this._handleVisibilityChange(), this._debug("#_initialize()", "end");
      }
    }
    async signInAnonymously(e) {
      var r, s, n;
      try {
        let i = await b(this.fetch, "POST", "".concat(this.url, "/signup"), { headers: this.headers, body: { data: (s = (r = e == null ? void 0 : e.options) === null || r === void 0 ? void 0 : r.data) !== null && s !== void 0 ? s : {}, gotrue_meta_security: { captcha_token: (n = e == null ? void 0 : e.options) === null || n === void 0 ? void 0 : n.captchaToken } }, xform: q }), { data: a, error: o } = i;
        if (o || !a) return this._returnResult({ data: { user: null, session: null }, error: o });
        let l = a.session, u = a.user;
        return a.session && (await this._saveSession(a.session), await this._notifyAllSubscribers("SIGNED_IN", l)), this._returnResult({ data: { user: u, session: l }, error: null });
      } catch (i) {
        if (w(i)) return this._returnResult({ data: { user: null, session: null }, error: i });
        throw i;
      }
    }
    async signUp(e) {
      var r, s, n;
      let i = null;
      try {
        let a;
        if ("email" in e) {
          let { email: c, password: f, options: d } = e, m = null, g = null;
          this.flowType === "pkce" && ([m, g, i] = await this._getCodeChallengeAndMethod()), a = await b(this.fetch, "POST", "".concat(this.url, "/signup"), { headers: this.headers, redirectTo: this._maybeAppendFlowIdToRedirect(d == null ? void 0 : d.emailRedirectTo, i), body: { email: c, password: f, data: (r = d == null ? void 0 : d.data) !== null && r !== void 0 ? r : {}, gotrue_meta_security: { captcha_token: d == null ? void 0 : d.captchaToken }, code_challenge: m, code_challenge_method: g }, xform: q });
        } else if ("phone" in e) {
          let { phone: c, password: f, options: d } = e;
          a = await b(this.fetch, "POST", "".concat(this.url, "/signup"), { headers: this.headers, body: { phone: c, password: f, data: (s = d == null ? void 0 : d.data) !== null && s !== void 0 ? s : {}, channel: (n = d == null ? void 0 : d.channel) !== null && n !== void 0 ? n : "sms", gotrue_meta_security: { captcha_token: d == null ? void 0 : d.captchaToken } }, xform: q });
        } else throw new Ye("You must provide either an email or phone number and a password");
        let { data: o, error: l } = a;
        if (l || !o) return await M(this.storage, this.storageKey, i), this._returnResult({ data: { user: null, session: null }, error: l });
        let u = o.session, h = o.user;
        return o.session && (await this._saveSession(o.session), await this._notifyAllSubscribers("SIGNED_IN", u)), this._returnResult({ data: { user: h, session: u }, error: null });
      } catch (a) {
        if (await M(this.storage, this.storageKey, i), w(a)) return this._returnResult({ data: { user: null, session: null }, error: a });
        throw a;
      }
    }
    async signInWithPassword(e) {
      try {
        let r;
        if ("email" in e) {
          let { email: i, password: a, options: o } = e;
          r = await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=password"), { headers: this.headers, body: { email: i, password: a, gotrue_meta_security: { captcha_token: o == null ? void 0 : o.captchaToken } }, xform: qr });
        } else if ("phone" in e) {
          let { phone: i, password: a, options: o } = e;
          r = await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=password"), { headers: this.headers, body: { phone: i, password: a, gotrue_meta_security: { captcha_token: o == null ? void 0 : o.captchaToken } }, xform: qr });
        } else throw new Ye("You must provide either an email or phone number and a password");
        let { data: s, error: n } = r;
        if (n) return this._returnResult({ data: { user: null, session: null }, error: n });
        if (!s || !s.session || !s.user) {
          let i = new we();
          return this._returnResult({ data: { user: null, session: null }, error: i });
        }
        return s.session && (await this._saveSession(s.session), await this._notifyAllSubscribers("SIGNED_IN", s.session)), this._returnResult({ data: Object.assign({ user: s.user, session: s.session }, s.weak_password ? { weakPassword: s.weak_password } : null), error: n });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: { user: null, session: null }, error: r });
        throw r;
      }
    }
    async signInWithOAuth(e) {
      var r, s, n, i;
      return await this._handleProviderSignIn(e.provider, { redirectTo: (r = e.options) === null || r === void 0 ? void 0 : r.redirectTo, scopes: (s = e.options) === null || s === void 0 ? void 0 : s.scopes, queryParams: (n = e.options) === null || n === void 0 ? void 0 : n.queryParams, skipBrowserRedirect: (i = e.options) === null || i === void 0 ? void 0 : i.skipBrowserRedirect });
    }
    async exchangeCodeForSession(e, r) {
      return await this.initializePromise, this.lock != null ? this._acquireLock(this.lockAcquireTimeout, async () => this._exchangeCodeForSession(e, r)) : this._exchangeCodeForSession(e, r);
    }
    async signInWithWeb3(e) {
      let { chain: r } = e;
      switch (r) {
        case "ethereum":
          return await this.signInWithEthereum(e);
        case "solana":
          return await this.signInWithSolana(e);
        default:
          throw new Error('@supabase/auth-js: Unsupported chain "'.concat(r, '"'));
      }
    }
    async signInWithEthereum(e) {
      var r, s, n, i, a, o, l, u, h, c, f;
      let d, m;
      if ("message" in e) d = e.message, m = e.signature;
      else {
        let { chain: g, wallet: y, statement: E, options: k } = e, _;
        if ($()) if (typeof y == "object") _ = y;
        else {
          let Y = window;
          if ("ethereum" in Y && typeof Y.ethereum == "object" && "request" in Y.ethereum && typeof Y.ethereum.request == "function") _ = Y.ethereum;
          else throw new Error("@supabase/auth-js: No compatible Ethereum wallet interface on the window object (window.ethereum) detected. Make sure the user already has a wallet installed and connected for this app. Prefer passing the wallet interface object directly to signInWithWeb3({ chain: 'ethereum', wallet: resolvedUserWallet }) instead.");
        }
        else {
          if (typeof y != "object" || !(k != null && k.url)) throw new Error("@supabase/auth-js: Both wallet and url must be specified in non-browser environments.");
          _ = y;
        }
        let R = new URL((r = k == null ? void 0 : k.url) !== null && r !== void 0 ? r : window.location.href), j = await _.request({ method: "eth_requestAccounts" }).then((Y) => Y).catch(() => {
          throw new Error("@supabase/auth-js: Wallet method eth_requestAccounts is missing or invalid");
        });
        if (!j || j.length === 0) throw new Error("@supabase/auth-js: No accounts available. Please ensure the wallet is connected.");
        let S = As(j[0]), O = (s = k == null ? void 0 : k.signInWithEthereum) === null || s === void 0 ? void 0 : s.chainId;
        if (!O) {
          let Y = await _.request({ method: "eth_chainId" });
          O = Wa(Y);
        }
        let Ns = { domain: R.host, address: S, statement: E, uri: R.href, version: "1", chainId: O, nonce: (n = k == null ? void 0 : k.signInWithEthereum) === null || n === void 0 ? void 0 : n.nonce, issuedAt: (a = (i = k == null ? void 0 : k.signInWithEthereum) === null || i === void 0 ? void 0 : i.issuedAt) !== null && a !== void 0 ? a : /* @__PURE__ */ new Date(), expirationTime: (o = k == null ? void 0 : k.signInWithEthereum) === null || o === void 0 ? void 0 : o.expirationTime, notBefore: (l = k == null ? void 0 : k.signInWithEthereum) === null || l === void 0 ? void 0 : l.notBefore, requestId: (u = k == null ? void 0 : k.signInWithEthereum) === null || u === void 0 ? void 0 : u.requestId, resources: (h = k == null ? void 0 : k.signInWithEthereum) === null || h === void 0 ? void 0 : h.resources };
        d = Ga(Ns), m = await _.request({ method: "personal_sign", params: [Ka(d), S] });
      }
      try {
        let { data: g, error: y } = await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=web3"), { headers: this.headers, body: Object.assign({ chain: "ethereum", message: d, signature: m }, !((c = e.options) === null || c === void 0) && c.captchaToken ? { gotrue_meta_security: { captcha_token: (f = e.options) === null || f === void 0 ? void 0 : f.captchaToken } } : null), xform: q });
        if (y) throw y;
        if (!g || !g.session || !g.user) {
          let E = new we();
          return this._returnResult({ data: { user: null, session: null }, error: E });
        }
        return g.session && (await this._saveSession(g.session), await this._notifyAllSubscribers("SIGNED_IN", g.session)), this._returnResult({ data: Object.assign({}, g), error: y });
      } catch (g) {
        if (w(g)) return this._returnResult({ data: { user: null, session: null }, error: g });
        throw g;
      }
    }
    async signInWithSolana(e) {
      var r, s, n, i, a, o, l, u, h, c, f, d;
      let m, g;
      if ("message" in e) m = e.message, g = e.signature;
      else {
        let { chain: y, wallet: E, statement: k, options: _ } = e, R;
        if ($()) if (typeof E == "object") R = E;
        else {
          let S = window;
          if ("solana" in S && typeof S.solana == "object" && ("signIn" in S.solana && typeof S.solana.signIn == "function" || "signMessage" in S.solana && typeof S.solana.signMessage == "function")) R = S.solana;
          else throw new Error("@supabase/auth-js: No compatible Solana wallet interface on the window object (window.solana) detected. Make sure the user already has a wallet installed and connected for this app. Prefer passing the wallet interface object directly to signInWithWeb3({ chain: 'solana', wallet: resolvedUserWallet }) instead.");
        }
        else {
          if (typeof E != "object" || !(_ != null && _.url)) throw new Error("@supabase/auth-js: Both wallet and url must be specified in non-browser environments.");
          R = E;
        }
        let j = new URL((r = _ == null ? void 0 : _.url) !== null && r !== void 0 ? r : window.location.href);
        if ("signIn" in R && R.signIn) {
          let S = await R.signIn(Object.assign(Object.assign(Object.assign({ issuedAt: (/* @__PURE__ */ new Date()).toISOString() }, _ == null ? void 0 : _.signInWithSolana), { version: "1", domain: j.host, uri: j.href }), k ? { statement: k } : null)), O;
          if (Array.isArray(S) && S[0] && typeof S[0] == "object") O = S[0];
          else if (S && typeof S == "object" && "signedMessage" in S && "signature" in S) O = S;
          else throw new Error("@supabase/auth-js: Wallet method signIn() returned unrecognized value");
          if ("signedMessage" in O && "signature" in O && (typeof O.signedMessage == "string" || O.signedMessage instanceof Uint8Array) && O.signature instanceof Uint8Array) m = typeof O.signedMessage == "string" ? O.signedMessage : new TextDecoder().decode(O.signedMessage), g = O.signature;
          else throw new Error("@supabase/auth-js: Wallet method signIn() API returned object without signedMessage and signature fields");
        } else {
          if (!("signMessage" in R) || typeof R.signMessage != "function" || !("publicKey" in R) || typeof R != "object" || !R.publicKey || !("toBase58" in R.publicKey) || typeof R.publicKey.toBase58 != "function") throw new Error("@supabase/auth-js: Wallet does not have a compatible signMessage() and publicKey.toBase58() API");
          m = ["".concat(j.host, " wants you to sign in with your Solana account:"), R.publicKey.toBase58(), ...k ? ["", k, ""] : [""], "Version: 1", "URI: ".concat(j.href), "Issued At: ".concat((n = (s = _ == null ? void 0 : _.signInWithSolana) === null || s === void 0 ? void 0 : s.issuedAt) !== null && n !== void 0 ? n : (/* @__PURE__ */ new Date()).toISOString()), ...!((i = _ == null ? void 0 : _.signInWithSolana) === null || i === void 0) && i.notBefore ? ["Not Before: ".concat(_.signInWithSolana.notBefore)] : [], ...!((a = _ == null ? void 0 : _.signInWithSolana) === null || a === void 0) && a.expirationTime ? ["Expiration Time: ".concat(_.signInWithSolana.expirationTime)] : [], ...!((o = _ == null ? void 0 : _.signInWithSolana) === null || o === void 0) && o.chainId ? ["Chain ID: ".concat(_.signInWithSolana.chainId)] : [], ...!((l = _ == null ? void 0 : _.signInWithSolana) === null || l === void 0) && l.nonce ? ["Nonce: ".concat(_.signInWithSolana.nonce)] : [], ...!((u = _ == null ? void 0 : _.signInWithSolana) === null || u === void 0) && u.requestId ? ["Request ID: ".concat(_.signInWithSolana.requestId)] : [], ...!((c = (h = _ == null ? void 0 : _.signInWithSolana) === null || h === void 0 ? void 0 : h.resources) === null || c === void 0) && c.length ? ["Resources", ..._.signInWithSolana.resources.map((O) => "- ".concat(O))] : []].join("\n");
          let S = await R.signMessage(new TextEncoder().encode(m), "utf8");
          if (!S || !(S instanceof Uint8Array)) throw new Error("@supabase/auth-js: Wallet signMessage() API returned an recognized value");
          g = S;
        }
      }
      try {
        let { data: y, error: E } = await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=web3"), { headers: this.headers, body: Object.assign({ chain: "solana", message: m, signature: fe(g) }, !((f = e.options) === null || f === void 0) && f.captchaToken ? { gotrue_meta_security: { captcha_token: (d = e.options) === null || d === void 0 ? void 0 : d.captchaToken } } : null), xform: q });
        if (E) throw E;
        if (!y || !y.session || !y.user) {
          let k = new we();
          return this._returnResult({ data: { user: null, session: null }, error: k });
        }
        return y.session && (await this._saveSession(y.session), await this._notifyAllSubscribers("SIGNED_IN", y.session)), this._returnResult({ data: Object.assign({}, y), error: E });
      } catch (y) {
        if (w(y)) return this._returnResult({ data: { user: null, session: null }, error: y });
        throw y;
      }
    }
    async _exchangeCodeForSession(e, r) {
      let s = (r == null ? void 0 : r.flowId) != null, n = s ? st(r == null ? void 0 : r.flowId) : $() ? st(Lr(window.location.href)[de]) : null;
      s && !n && this._debug("#_exchangeCodeForSession()", "provided flowId is not a valid flow id", r == null ? void 0 : r.flowId);
      let { verifier: i, flowId: a } = s && !n ? { verifier: null, flowId: null } : await Aa(this.storage, this.storageKey, n), [o, l] = (i != null ? i : "").split("/");
      try {
        if (!o && this.flowType === "pkce") throw new ca();
        let { data: u, error: h } = await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=pkce"), { headers: this.headers, body: { auth_code: e, code_verifier: o }, xform: q });
        if (await M(this.storage, this.storageKey, a), h) throw h;
        if (!u || !u.session || !u.user) {
          let c = new we();
          return this._returnResult({ data: { user: null, session: null, redirectType: null }, error: c });
        }
        return u.session && (await this._saveSession(u.session), await this._notifyAllSubscribers(l === "recovery" ? "PASSWORD_RECOVERY" : "SIGNED_IN", u.session)), this._returnResult({ data: Object.assign(Object.assign({}, u), { redirectType: l != null ? l : null }), error: h });
      } catch (u) {
        if (await M(this.storage, this.storageKey, a), w(u)) return this._returnResult({ data: { user: null, session: null, redirectType: null }, error: u });
        throw u;
      }
    }
    async signInWithIdToken(e) {
      try {
        let { options: r, provider: s, token: n, access_token: i, nonce: a } = e, o = await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=id_token"), { headers: this.headers, body: { provider: s, id_token: n, access_token: i, nonce: a, gotrue_meta_security: { captcha_token: r == null ? void 0 : r.captchaToken } }, xform: q }), { data: l, error: u } = o;
        if (u) return this._returnResult({ data: { user: null, session: null }, error: u });
        if (!l || !l.session || !l.user) {
          let h = new we();
          return this._returnResult({ data: { user: null, session: null }, error: h });
        }
        return l.session && (await this._saveSession(l.session), await this._notifyAllSubscribers("SIGNED_IN", l.session)), this._returnResult({ data: l, error: u });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: { user: null, session: null }, error: r });
        throw r;
      }
    }
    async signInWithOtp(e) {
      var r, s, n, i, a;
      let o = null;
      try {
        if ("email" in e) {
          let { email: l, options: u } = e, h = null, c = null;
          this.flowType === "pkce" && ([h, c, o] = await this._getCodeChallengeAndMethod());
          let { error: f } = await b(this.fetch, "POST", "".concat(this.url, "/otp"), { headers: this.headers, body: { email: l, data: (r = u == null ? void 0 : u.data) !== null && r !== void 0 ? r : {}, create_user: (s = u == null ? void 0 : u.shouldCreateUser) !== null && s !== void 0 ? s : true, gotrue_meta_security: { captcha_token: u == null ? void 0 : u.captchaToken }, code_challenge: h, code_challenge_method: c }, redirectTo: this._maybeAppendFlowIdToRedirect(u == null ? void 0 : u.emailRedirectTo, o) });
          return this._returnResult({ data: { user: null, session: null }, error: f });
        }
        if ("phone" in e) {
          let { phone: l, options: u } = e, { data: h, error: c } = await b(this.fetch, "POST", "".concat(this.url, "/otp"), { headers: this.headers, body: { phone: l, data: (n = u == null ? void 0 : u.data) !== null && n !== void 0 ? n : {}, create_user: (i = u == null ? void 0 : u.shouldCreateUser) !== null && i !== void 0 ? i : true, gotrue_meta_security: { captcha_token: u == null ? void 0 : u.captchaToken }, channel: (a = u == null ? void 0 : u.channel) !== null && a !== void 0 ? a : "sms" } });
          return this._returnResult({ data: { user: null, session: null, messageId: h == null ? void 0 : h.message_id }, error: c });
        }
        throw new Ye("You must provide either an email or phone number.");
      } catch (l) {
        if (await M(this.storage, this.storageKey, o), w(l)) return this._returnResult({ data: { user: null, session: null }, error: l });
        throw l;
      }
    }
    async verifyOtp(e) {
      var r, s;
      try {
        let n, i;
        "options" in e && (n = (r = e.options) === null || r === void 0 ? void 0 : r.redirectTo, i = (s = e.options) === null || s === void 0 ? void 0 : s.captchaToken);
        let { data: a, error: o } = await b(this.fetch, "POST", "".concat(this.url, "/verify"), { headers: this.headers, body: Object.assign(Object.assign({}, e), { gotrue_meta_security: { captcha_token: i } }), redirectTo: n, xform: q });
        if (o) throw o;
        if (!a) throw new Error("An error occurred on token verification.");
        let l = a.session, u = a.user;
        return l != null && l.access_token && (await this._saveSession(l), await this._notifyAllSubscribers(e.type == "recovery" ? "PASSWORD_RECOVERY" : "SIGNED_IN", l)), this._returnResult({ data: { user: u, session: l }, error: null });
      } catch (n) {
        if (w(n)) return this._returnResult({ data: { user: null, session: null }, error: n });
        throw n;
      }
    }
    async signInWithSSO(e) {
      var r, s, n, i;
      let a = null;
      try {
        let o = null, l = null;
        this.flowType === "pkce" && ([o, l, a] = await this._getCodeChallengeAndMethod());
        let u = await b(this.fetch, "POST", "".concat(this.url, "/sso"), { body: Object.assign(Object.assign(Object.assign(Object.assign(Object.assign({}, "providerId" in e ? { provider_id: e.providerId } : null), "domain" in e ? { domain: e.domain } : null), { redirect_to: this._maybeAppendFlowIdToRedirect((r = e.options) === null || r === void 0 ? void 0 : r.redirectTo, a) }), !((s = e == null ? void 0 : e.options) === null || s === void 0) && s.captchaToken ? { gotrue_meta_security: { captcha_token: e.options.captchaToken } } : null), { skip_http_redirect: true, code_challenge: o, code_challenge_method: l }), headers: this.headers, xform: Da });
        return !((n = u.data) === null || n === void 0) && n.url && $() && !(!((i = e.options) === null || i === void 0) && i.skipBrowserRedirect) && window.location.assign(u.data.url), this._returnResult(u);
      } catch (o) {
        if (await M(this.storage, this.storageKey, a), w(o)) return this._returnResult({ data: null, error: o });
        throw o;
      }
    }
    async reauthenticate() {
      return await this.initializePromise, this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => await this._reauthenticate()) : await this._reauthenticate();
    }
    async _reauthenticate() {
      try {
        return await this._useSession(async (e) => {
          let { data: { session: r }, error: s } = e;
          if (s) throw s;
          if (!r) throw new C();
          let { error: n } = await b(this.fetch, "GET", "".concat(this.url, "/reauthenticate"), { headers: this.headers, jwt: r.access_token });
          return this._returnResult({ data: { user: null, session: null }, error: n });
        });
      } catch (e) {
        if (w(e)) return this._returnResult({ data: { user: null, session: null }, error: e });
        throw e;
      }
    }
    async resend(e) {
      let r = null;
      try {
        let s = "".concat(this.url, "/resend");
        if ("email" in e) {
          let { email: n, type: i, options: a } = e, o = null, l = null;
          this.flowType === "pkce" && ([o, l, r] = await this._getCodeChallengeAndMethod());
          let { error: u } = await b(this.fetch, "POST", s, { headers: this.headers, body: { email: n, type: i, gotrue_meta_security: { captcha_token: a == null ? void 0 : a.captchaToken }, code_challenge: o, code_challenge_method: l }, redirectTo: this._maybeAppendFlowIdToRedirect(a == null ? void 0 : a.emailRedirectTo, r) });
          return u && await M(this.storage, this.storageKey, r), this._returnResult({ data: { user: null, session: null }, error: u });
        } else if ("phone" in e) {
          let { phone: n, type: i, options: a } = e, { data: o, error: l } = await b(this.fetch, "POST", s, { headers: this.headers, body: { phone: n, type: i, gotrue_meta_security: { captcha_token: a == null ? void 0 : a.captchaToken } } });
          return this._returnResult({ data: { user: null, session: null, messageId: o == null ? void 0 : o.message_id }, error: l });
        }
        throw new Ye("You must provide either an email or phone number and a type");
      } catch (s) {
        if (await M(this.storage, this.storageKey, r), w(s)) return this._returnResult({ data: { user: null, session: null }, error: s });
        throw s;
      }
    }
    async getSession() {
      return await this.initializePromise, this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => this._useSession(async (e) => e)) : await this._useSession(async (e) => e);
    }
    async _acquireLock(e, r) {
      this._debug("#_acquireLock", "begin", e);
      try {
        if (this.lockAcquired) {
          let s = this.pendingInLock.length ? this.pendingInLock[this.pendingInLock.length - 1] : Promise.resolve(), n = (async () => (await s, await r()))();
          return this.pendingInLock.push((async () => {
            try {
              await n;
            } catch (i) {
            }
          })()), n;
        }
        return await this.lock("lock:".concat(this.storageKey), e, async () => {
          this._debug("#_acquireLock", "lock acquired for storage key", this.storageKey);
          try {
            this.lockAcquired = true;
            let s = r();
            for (this.pendingInLock.push((async () => {
              try {
                await s;
              } catch (n) {
              }
            })()), await s; this.pendingInLock.length; ) {
              let n = [...this.pendingInLock];
              await Promise.all(n), this.pendingInLock.splice(0, n.length);
            }
            return await s;
          } finally {
            this._debug("#_acquireLock", "lock released for storage key", this.storageKey), this.lockAcquired = false;
          }
        });
      } finally {
        this._debug("#_acquireLock", "end");
      }
    }
    async _useSession(e) {
      this._debug("#_useSession", "begin");
      try {
        let r = await this.__loadSession();
        return await e(r);
      } finally {
        this._debug("#_useSession", "end");
      }
    }
    async __loadSession() {
      this._debug("#__loadSession()", "begin"), this.lock != null && !this.lockAcquired && this._debug("#__loadSession()", "used outside of an acquired lock!", new Error().stack);
      try {
        let e = null, r = await N(this.storage, this.storageKey);
        if (this._debug("#getSession()", "session from storage", r), r !== null && (this._isValidSession(r) ? e = r : (this._debug("#getSession()", "session from storage is not valid"), await this._removeSession())), !e) return { data: { session: null }, error: null };
        let s = e.expires_at ? e.expires_at * 1e3 - Date.now() < At : false;
        if (this._debug("#__loadSession()", "session has".concat(s ? "" : " not", " expired"), "expires_at", e.expires_at), !s) return { data: { session: await this._hydrateSessionUser(e) }, error: null };
        let { data: n, error: i } = await this._callRefreshToken(e.refresh_token);
        if (i) {
          let a = await N(this.storage, this.storageKey);
          return a && this._isValidSession(a) && a.expires_at && a.expires_at * 1e3 > Date.now() ? this._returnResult({ data: { session: await this._hydrateSessionUser(a) }, error: null }) : this._returnResult({ data: { session: null }, error: i });
        }
        return this._returnResult({ data: { session: n }, error: null });
      } finally {
        this._debug("#__loadSession()", "end");
      }
    }
    async _hydrateSessionUser(e) {
      if (this.userStorage) {
        let r = await N(this.userStorage, this.storageKey + "-user");
        e.user = r != null && r.user ? r.user : Ot();
      }
      if (this.storage.isServer && e.user && !e.user.__isUserNotAvailableProxy) {
        let r = { value: this.suppressGetSessionWarning };
        e.user = La(e.user, r), r.value && (this.suppressGetSessionWarning = true);
      }
      return e;
    }
    async getUser(e) {
      if (e) return await this._getUser(e);
      await this.initializePromise;
      let r;
      return this.lock != null ? r = await this._acquireLock(this.lockAcquireTimeout, async () => await this._getUser()) : r = await this._getUser(), r.data.user && (this.suppressGetSessionWarning = true), r;
    }
    async _getUser(e) {
      try {
        return e ? await b(this.fetch, "GET", "".concat(this.url, "/user"), { headers: this.headers, jwt: e, xform: ae }) : await this._useSession(async (r) => {
          var s, n, i;
          let { data: a, error: o } = r;
          if (o) throw o;
          return !(!((s = a.session) === null || s === void 0) && s.access_token) && !this.hasCustomAuthorizationHeader ? { data: { user: null }, error: new C() } : await b(this.fetch, "GET", "".concat(this.url, "/user"), { headers: this.headers, jwt: (i = (n = a.session) === null || n === void 0 ? void 0 : n.access_token) !== null && i !== void 0 ? i : void 0, xform: ae });
        });
      } catch (r) {
        if (w(r)) return ze(r) && await this._removeSession(), this._returnResult({ data: { user: null }, error: r });
        throw r;
      }
    }
    async updateUser(e, r = {}) {
      return await this.initializePromise, this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => await this._updateUser(e, r)) : await this._updateUser(e, r);
    }
    async _updateUser(e, r = {}) {
      let s = null;
      try {
        return await this._useSession(async (n) => {
          let { data: i, error: a } = n;
          if (a) throw a;
          if (!i.session) throw new C();
          let o = i.session, l = null, u = null;
          this.flowType === "pkce" && e.email != null && ([l, u, s] = await this._getCodeChallengeAndMethod());
          let { data: h, error: c } = await b(this.fetch, "PUT", "".concat(this.url, "/user"), { headers: this.headers, redirectTo: this._maybeAppendFlowIdToRedirect(r == null ? void 0 : r.emailRedirectTo, s), body: Object.assign(Object.assign({}, e), { code_challenge: l, code_challenge_method: u }), jwt: o.access_token, xform: ae });
          if (c) throw c;
          return o.user = h.user, await this._saveSession(o), await this._notifyAllSubscribers("USER_UPDATED", o), this._returnResult({ data: { user: o.user }, error: null });
        });
      } catch (n) {
        if (await M(this.storage, this.storageKey, s), w(n)) return this._returnResult({ data: { user: null }, error: n });
        throw n;
      }
    }
    async setSession(e) {
      return await this.initializePromise, this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => await this._setSession(e)) : await this._setSession(e);
    }
    async _setSession(e) {
      try {
        if (!e.access_token || !e.refresh_token) throw new C();
        let r = Date.now() / 1e3, s = r, n = true, i = null, { payload: a } = Ze(e.access_token);
        if (a.exp && (s = a.exp, n = s <= r), n) {
          let { data: o, error: l } = await this._callRefreshToken(e.refresh_token);
          if (l) return this._returnResult({ data: { user: null, session: null }, error: l });
          if (!o) return { data: { user: null, session: null }, error: null };
          i = o;
        } else {
          let { data: o, error: l } = await this._getUser(e.access_token);
          if (l) return this._returnResult({ data: { user: null, session: null }, error: l });
          i = { access_token: e.access_token, refresh_token: e.refresh_token, user: o.user, token_type: "bearer", expires_in: s - r, expires_at: s }, await this._saveSession(i), await this._notifyAllSubscribers("SIGNED_IN", i);
        }
        return this._returnResult({ data: { user: i.user, session: i }, error: null });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: { session: null, user: null }, error: r });
        throw r;
      }
    }
    async refreshSession(e) {
      return await this.initializePromise, this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => await this._refreshSession(e)) : await this._refreshSession(e);
    }
    async _refreshSession(e) {
      try {
        return await this._useSession(async (r) => {
          var s;
          if (!e) {
            let { data: a, error: o } = r;
            if (o) throw o;
            e = (s = a.session) !== null && s !== void 0 ? s : void 0;
          }
          if (!(e != null && e.refresh_token)) throw new C();
          let { data: n, error: i } = await this._callRefreshToken(e.refresh_token);
          return i ? this._returnResult({ data: { user: null, session: null }, error: i }) : n ? this._returnResult({ data: { user: n.user, session: n }, error: null }) : this._returnResult({ data: { user: null, session: null }, error: null });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: { user: null, session: null }, error: r });
        throw r;
      }
    }
    async _getSessionFromURL(e, r) {
      var s;
      try {
        if (!$()) throw new Xe("No browser detected.");
        if (e.error || e.error_description || e.error_code) throw new Xe(e.error_description || "Error in URL with unspecified error_description", { error: e.error || "unspecified_error", code: e.error_code || "unspecified_code" });
        switch (r) {
          case "implicit":
            if (this.flowType === "pkce") throw new Ir("Not a valid PKCE flow url.");
            break;
          case "pkce":
            if (this.flowType === "implicit") throw new Xe("Not a valid implicit grant flow url.");
            break;
          default:
        }
        if (r === "pkce") {
          if (this._debug("#_initialize()", "begin", "is PKCE flow", true), !e.code) throw new Ir("No code detected.");
          let { data: _, error: R } = await this._exchangeCodeForSession(e.code, { flowId: e[de] });
          if (R) throw R;
          let j = new URL(window.location.href);
          return j.searchParams.delete("code"), j.searchParams.delete(de), window.history.replaceState(window.history.state, "", j.toString()), { data: { session: _.session, redirectType: (s = _.redirectType) !== null && s !== void 0 ? s : null }, error: null };
        }
        let { provider_token: n, provider_refresh_token: i, access_token: a, refresh_token: o, expires_in: l, expires_at: u, token_type: h } = e;
        if (!a || !l || !o || !h) throw new Xe("No session defined in URL");
        let c = Math.round(Date.now() / 1e3), f = parseInt(l), d = c + f;
        u && (d = parseInt(u));
        let m = d - c;
        m * 1e3 <= te && console.warn("@supabase/gotrue-js: Session as retrieved from URL expires in ".concat(m, "s, should have been closer to ").concat(f, "s"));
        let g = d - f;
        c - g >= 120 ? console.warn("@supabase/gotrue-js: Session as retrieved from URL was issued over 120s ago, URL could be stale", g, d, c) : c - g < 0 && console.warn("@supabase/gotrue-js: Session as retrieved from URL was issued in the future? Check the device clock for skew", g, d, c);
        let { data: y, error: E } = await this._getUser(a);
        if (E) throw E;
        let k = { provider_token: n, provider_refresh_token: i, access_token: a, expires_in: f, expires_at: d, refresh_token: o, token_type: h, user: y.user };
        return window.location.hash = "", this._debug("#_getSessionFromURL()", "clearing window.location.hash"), this._returnResult({ data: { session: k, redirectType: e.type }, error: null });
      } catch (n) {
        if (w(n)) return this._returnResult({ data: { session: null, redirectType: null }, error: n });
        throw n;
      }
    }
    _isImplicitGrantCallback(e) {
      return typeof this.detectSessionInUrl == "function" ? this.detectSessionInUrl(new URL(window.location.href), e) : !!(e.access_token || e.error || e.error_description || e.error_code);
    }
    async _isPKCECallback(e) {
      if (!e.code) return false;
      let r = st(e[de]);
      return r && await N(this.storage, Ae(this.storageKey, r)) ? true : !!await N(this.storage, "".concat(this.storageKey, "-code-verifier"));
    }
    async signOut(e = { scope: "global" }) {
      return await this.initializePromise, this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => await this._signOut(e)) : await this._signOut(e);
    }
    async _signOut({ scope: e } = { scope: "global" }) {
      return await this._useSession(async (r) => {
        var s;
        let n = async () => {
          await this._removeSession();
        }, { data: i, error: a } = r;
        if (a && !ze(a)) return this._returnResult({ error: a });
        let o = (s = i.session) === null || s === void 0 ? void 0 : s.access_token;
        if (o) {
          let { error: l } = await this.admin.signOut(o, e);
          if (l && !(Or(l) && (l.status === 404 || l.status === 401 || l.status === 403) || ze(l))) return e !== "others" && await n(), this._returnResult({ error: l });
        }
        return e !== "others" && await n(), this._returnResult({ error: null });
      });
    }
    onAuthStateChange(e) {
      let r = ma(), s = { id: r, callback: e, unsubscribe: () => {
        this._debug("#unsubscribe()", "state change callback with id removed", r), this.stateChangeEmitters.delete(r);
      } };
      return this._debug("#onAuthStateChange()", "registered callback with id", r), this.stateChangeEmitters.set(r, s), (async () => (await this.initializePromise, this.lock != null ? await this._acquireLock(this.lockAcquireTimeout, async () => {
        this._emitInitialSession(r);
      }) : await this._emitInitialSession(r)))(), { data: { subscription: s } };
    }
    async _emitInitialSession(e) {
      return await this._useSession(async (r) => {
        var s, n;
        try {
          let { data: { session: i }, error: a } = r;
          if (a) throw a;
          await ((s = this.stateChangeEmitters.get(e)) === null || s === void 0 ? void 0 : s.callback("INITIAL_SESSION", i)), this._debug("INITIAL_SESSION", "callback id", e, "session", i);
        } catch (i) {
          if (await ((n = this.stateChangeEmitters.get(e)) === null || n === void 0 ? void 0 : n.callback("INITIAL_SESSION", null)), this._debug("INITIAL_SESSION", "callback id", e, "error", i), Pr(i)) return;
          ze(i) || Qe(i) || Or(i) && (i.code === "refresh_token_not_found" || i.code === "refresh_token_already_used" || i.code === "session_expired") ? console.warn(i) : console.error(i);
        }
      });
    }
    async resetPasswordForEmail(e, r = {}) {
      let s = null, n = null, i = null;
      this.flowType === "pkce" && ([s, n, i] = await this._getCodeChallengeAndMethod(true));
      try {
        return await b(this.fetch, "POST", "".concat(this.url, "/recover"), { body: { email: e, code_challenge: s, code_challenge_method: n, gotrue_meta_security: { captcha_token: r.captchaToken } }, headers: this.headers, redirectTo: this._maybeAppendFlowIdToRedirect(r.redirectTo, i) });
      } catch (a) {
        if (await M(this.storage, this.storageKey, i), w(a)) return this._returnResult({ data: null, error: a });
        throw a;
      }
    }
    async getUserIdentities() {
      var e;
      try {
        let { data: r, error: s } = await this.getUser();
        if (s) throw s;
        return this._returnResult({ data: { identities: (e = r.user.identities) !== null && e !== void 0 ? e : [] }, error: null });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async linkIdentity(e) {
      return "token" in e ? this.linkIdentityIdToken(e) : this.linkIdentityOAuth(e);
    }
    async linkIdentityOAuth(e) {
      var r;
      let s = null;
      try {
        let { data: n, error: i } = await this._useSession(async (a) => {
          var o, l, u, h, c;
          let { data: f, error: d } = a;
          if (d) throw d;
          let { url: m, flowId: g } = await this._getUrlForProvider("".concat(this.url, "/user/identities/authorize"), e.provider, { redirectTo: (o = e.options) === null || o === void 0 ? void 0 : o.redirectTo, scopes: (l = e.options) === null || l === void 0 ? void 0 : l.scopes, queryParams: (u = e.options) === null || u === void 0 ? void 0 : u.queryParams, skipBrowserRedirect: true });
          return s = g, await b(this.fetch, "GET", m, { headers: this.headers, jwt: (c = (h = f.session) === null || h === void 0 ? void 0 : h.access_token) !== null && c !== void 0 ? c : void 0 });
        });
        if (i) throw i;
        return $() && !(!((r = e.options) === null || r === void 0) && r.skipBrowserRedirect) && window.location.assign(n == null ? void 0 : n.url), this._returnResult({ data: { provider: e.provider, url: n == null ? void 0 : n.url, flowId: s }, error: null });
      } catch (n) {
        if (w(n)) return this._returnResult({ data: { provider: e.provider, url: null, flowId: s }, error: n });
        throw n;
      }
    }
    async linkIdentityIdToken(e) {
      return await this._useSession(async (r) => {
        var s;
        try {
          let { error: n, data: { session: i } } = r;
          if (n) throw n;
          let { options: a, provider: o, token: l, access_token: u, nonce: h } = e, c = await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=id_token"), { headers: this.headers, jwt: (s = i == null ? void 0 : i.access_token) !== null && s !== void 0 ? s : void 0, body: { provider: o, id_token: l, access_token: u, nonce: h, link_identity: true, gotrue_meta_security: { captcha_token: a == null ? void 0 : a.captchaToken } }, xform: q }), { data: f, error: d } = c;
          return d ? this._returnResult({ data: { user: null, session: null }, error: d }) : !f || !f.session || !f.user ? this._returnResult({ data: { user: null, session: null }, error: new we() }) : (f.session && (await this._saveSession(f.session), await this._notifyAllSubscribers("USER_UPDATED", f.session)), this._returnResult({ data: f, error: d }));
        } catch (n) {
          if (await M(this.storage, this.storageKey, null), w(n)) return this._returnResult({ data: { user: null, session: null }, error: n });
          throw n;
        }
      });
    }
    async unlinkIdentity(e) {
      try {
        return await this._useSession(async (r) => {
          var s, n;
          let { data: i, error: a } = r;
          if (a) throw a;
          return await b(this.fetch, "DELETE", "".concat(this.url, "/user/identities/").concat(e.identity_id), { headers: this.headers, jwt: (n = (s = i.session) === null || s === void 0 ? void 0 : s.access_token) !== null && n !== void 0 ? n : void 0 });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _refreshAccessToken(e) {
      let r = "#_refreshAccessToken()";
      this._debug(r, "begin");
      try {
        let s = Date.now();
        return await va(async (n) => (n > 0 && await ba(200 * Math.pow(2, n - 1)), this._debug(r, "refreshing attempt", n), await b(this.fetch, "POST", "".concat(this.url, "/token?grant_type=refresh_token"), { body: { refresh_token: e }, headers: this.headers, xform: q })), (n, i) => {
          let a = 200 * Math.pow(2, n);
          return i && Qe(i) && Date.now() + a - s < te;
        });
      } catch (s) {
        if (this._debug(r, "error", s), w(s)) return this._returnResult({ data: { session: null, user: null }, error: s });
        throw s;
      } finally {
        this._debug(r, "end");
      }
    }
    _isValidSession(e) {
      return typeof e == "object" && e !== null && "access_token" in e && "refresh_token" in e && "expires_at" in e;
    }
    async _handleProviderSignIn(e, r) {
      let { url: s, flowId: n } = await this._getUrlForProvider("".concat(this.url, "/authorize"), e, { redirectTo: r.redirectTo, scopes: r.scopes, queryParams: r.queryParams });
      return this._debug("#_handleProviderSignIn()", "provider", e, "options", r, "url", s), $() && !r.skipBrowserRedirect && window.location.assign(s), { data: { provider: e, url: s, flowId: n }, error: null };
    }
    async _recoverAndRefresh() {
      var e, r;
      let s = "#_recoverAndRefresh()";
      this._debug(s, "begin");
      try {
        let n = await N(this.storage, this.storageKey);
        if (n && this.userStorage) {
          let a = await N(this.userStorage, this.storageKey + "-user");
          !this.storage.isServer && Object.is(this.storage, this.userStorage) && !a && (a = { user: n.user }, await se(this.userStorage, this.storageKey + "-user", a)), n.user = (e = a == null ? void 0 : a.user) !== null && e !== void 0 ? e : Ot();
        } else if (n && !n.user && !n.user) {
          let a = await N(this.storage, this.storageKey + "-user");
          a && a != null && a.user ? (n.user = a.user, await U(this.storage, this.storageKey + "-user"), await se(this.storage, this.storageKey, n)) : n.user = Ot();
        }
        if (this._debug(s, "session from storage", n), !this._isValidSession(n)) {
          this._debug(s, "session is not valid"), n !== null && await this._removeSession();
          return;
        }
        let i = ((r = n.expires_at) !== null && r !== void 0 ? r : 1 / 0) * 1e3 - Date.now() < At;
        if (this._debug(s, "session has".concat(i ? "" : " not", " expired with margin of ").concat(At, "s")), i) {
          if (this.autoRefreshToken && n.refresh_token) {
            let { error: a } = await this._callRefreshToken(n.refresh_token);
            a && (Pr(a) ? this._debug(s, "refresh discarded by commit guard", a) : this._debug(s, "refresh failed", a));
          }
        } else if (n.user && n.user.__isUserNotAvailableProxy === true) try {
          let { data: a, error: o } = await this._getUser(n.access_token);
          !o && a != null && a.user ? (n.user = a.user, await this._saveSession(n), await this._notifyAllSubscribers("SIGNED_IN", n)) : this._debug(s, "could not get user data, skipping SIGNED_IN notification");
        } catch (a) {
          console.error("Error getting user data:", a), this._debug(s, "error getting user data, skipping SIGNED_IN notification", a);
        }
        else await this._notifyAllSubscribers("SIGNED_IN", n);
      } catch (n) {
        this._debug(s, "error", n), Qe(n) ? console.warn(n) : console.error(n);
        return;
      } finally {
        this._debug(s, "end");
      }
    }
    async _callRefreshToken(e) {
      var r, s;
      if (!e) throw new C();
      if (this.refreshingDeferred) return this.refreshingDeferred.promise;
      if (this.lastRefreshFailure && this.lastRefreshFailure.refreshToken === e && Date.now() < this.lastRefreshFailure.expiresAt) return this._debug("#_callRefreshToken()", "returning cached failure (cooldown active)"), this.lastRefreshFailure.result;
      let n = "#_callRefreshToken()";
      this._debug(n, "begin");
      try {
        this.refreshingDeferred = new Es(), this.refreshingDeferred.promise.then(void 0, () => {
        });
        let i = await N(this.storage, this.storageKey), { data: a, error: o } = await this._refreshAccessToken(e);
        if (o) throw o;
        if (!a.session) throw new C();
        let l = await N(this.storage, this.storageKey);
        if (i !== null && (l === null || l.refresh_token !== i.refresh_token)) {
          this._debug(n, "commit guard: storage changed since refresh started, discarding rotated tokens", { startedWith: "present", nowHolds: l ? "replaced" : "cleared" });
          let c = { data: null, error: new jr() };
          return this.refreshingDeferred.resolve(c), c;
        }
        let u = this._sessionRemovalEpoch;
        if (await this._saveSession(a.session), this._sessionRemovalEpoch !== u) {
          this._debug(n, "commit guard (post-save): _removeSession ran during _saveSession, undoing write"), await U(this.storage, this.storageKey), this.userStorage && await U(this.userStorage, this.storageKey + "-user");
          let c = { data: null, error: new jr() };
          return this.refreshingDeferred.resolve(c), c;
        }
        await this._notifyAllSubscribers("TOKEN_REFRESHED", a.session);
        let h = { data: a.session, error: null };
        return this.lastRefreshFailure = null, this.refreshingDeferred.resolve(h), h;
      } catch (i) {
        if (this._debug(n, "error", i), w(i)) {
          let a = { data: null, error: i };
          if (!Qe(i)) {
            let o = await N(this.storage, this.storageKey);
            o != null && o.expires_at && o.expires_at * 1e3 > Date.now() ? this._debug(n, "proactive refresh failed, access token still valid — preserving session") : await this._removeSession();
          }
          return this.lastRefreshFailure = { refreshToken: e, result: a, expiresAt: Date.now() + ra }, (r = this.refreshingDeferred) === null || r === void 0 || r.resolve(a), a;
        }
        throw (s = this.refreshingDeferred) === null || s === void 0 || s.reject(i), i;
      } finally {
        this.refreshingDeferred = null, this._debug(n, "end");
      }
    }
    async _notifyAllSubscribers(e, r, s = true) {
      if (this._pendingInitNotifications !== null && s) {
        this._pendingInitNotifications.push({ event: e, session: r, broadcast: s });
        return;
      }
      let n = "#_notifyAllSubscribers(".concat(e, ")");
      this._debug(n, "begin", r, "broadcast = ".concat(s));
      try {
        this.broadcastChannel && s && this.broadcastChannel.postMessage({ event: e, session: r });
        let i = [], a = Array.from(this.stateChangeEmitters.values()).map(async (o) => {
          try {
            await o.callback(e, r);
          } catch (l) {
            i.push(l);
          }
        });
        if (await Promise.all(a), i.length > 0) {
          for (let o = 0; o < i.length; o += 1) console.error(i[o]);
          throw i[0];
        }
      } finally {
        this._debug(n, "end");
      }
    }
    async _saveSession(e) {
      this._debug("#_saveSession()", e), this.suppressGetSessionWarning = true;
      let r = Object.assign({}, e), s = r.user && r.user.__isUserNotAvailableProxy === true;
      if (this.userStorage) {
        !s && r.user && await se(this.userStorage, this.storageKey + "-user", { user: r.user });
        let n = Object.assign({}, r);
        delete n.user;
        let i = Ur(n);
        await se(this.storage, this.storageKey, i);
      } else {
        let n = Ur(r);
        await se(this.storage, this.storageKey, n);
      }
    }
    async _removeSession() {
      this._sessionRemovalEpoch += 1, this._debug("#_removeSession()"), this.lastRefreshFailure = null, this.suppressGetSessionWarning = false, await U(this.storage, this.storageKey), await Oa(this.storage, this.storageKey), await U(this.storage, this.storageKey + "-user"), this.userStorage && await U(this.userStorage, this.storageKey + "-user"), await this._notifyAllSubscribers("SIGNED_OUT", null);
    }
    _removeVisibilityChangedCallback() {
      this._debug("#_removeVisibilityChangedCallback()");
      let e = this.visibilityChangedCallback;
      this.visibilityChangedCallback = null;
      try {
        e && $() && window != null && window.removeEventListener && window.removeEventListener("visibilitychange", e);
      } catch (r) {
        console.error("removing visibilitychange callback failed", r);
      }
    }
    async _startAutoRefresh() {
      await this._stopAutoRefresh(), this._debug("#_startAutoRefresh()");
      let e = setInterval(() => this._autoRefreshTokenTick(), te);
      this.autoRefreshTicker = e, e && typeof e == "object" && typeof e.unref == "function" ? e.unref() : typeof Deno != "undefined" && typeof Deno.unrefTimer == "function" && Deno.unrefTimer(e);
      let r = setTimeout(async () => {
        await this.initializePromise, await this._autoRefreshTokenTick();
      }, 0);
      this.autoRefreshTickTimeout = r, r && typeof r == "object" && typeof r.unref == "function" ? r.unref() : typeof Deno != "undefined" && typeof Deno.unrefTimer == "function" && Deno.unrefTimer(r);
    }
    async _stopAutoRefresh() {
      this._debug("#_stopAutoRefresh()");
      let e = this.autoRefreshTicker;
      this.autoRefreshTicker = null, e && clearInterval(e);
      let r = this.autoRefreshTickTimeout;
      this.autoRefreshTickTimeout = null, r && clearTimeout(r);
    }
    async startAutoRefresh() {
      this._removeVisibilityChangedCallback(), await this._startAutoRefresh();
    }
    async stopAutoRefresh() {
      this._removeVisibilityChangedCallback(), await this._stopAutoRefresh();
    }
    async dispose() {
      var e;
      this._removeVisibilityChangedCallback(), await this._stopAutoRefresh(), (e = this.broadcastChannel) === null || e === void 0 || e.close(), this.broadcastChannel = null, this.stateChangeEmitters.clear();
    }
    async _autoRefreshTokenTick() {
      if (this._debug("#_autoRefreshTokenTick()", "begin"), this.lock != null) {
        try {
          await this._acquireLock(0, async () => {
            try {
              let e = Date.now();
              try {
                return await this._useSession(async (r) => {
                  let { data: { session: s } } = r;
                  if (!s || !s.refresh_token || !s.expires_at) {
                    this._debug("#_autoRefreshTokenTick()", "no session");
                    return;
                  }
                  let n = Math.floor((s.expires_at * 1e3 - e) / te);
                  this._debug("#_autoRefreshTokenTick()", "access token expires in ".concat(n, " ticks, a tick lasts ").concat(te, "ms, refresh threshold is ").concat($e, " ticks")), n <= $e && await this._callRefreshToken(s.refresh_token);
                });
              } catch (r) {
                console.error("Auto refresh tick failed with error. This is likely a transient error.", r);
              }
            } finally {
              this._debug("#_autoRefreshTokenTick()", "end");
            }
          });
        } catch (e) {
          if (e instanceof qe) this._debug("auto refresh token tick lock not available");
          else throw e;
        }
        return;
      }
      if (this.refreshingDeferred !== null) {
        this._debug("#_autoRefreshTokenTick()", "refresh already in flight, skipping");
        return;
      }
      try {
        let e = Date.now();
        try {
          await this._useSession(async (r) => {
            let { data: { session: s } } = r;
            if (!s || !s.refresh_token || !s.expires_at) {
              this._debug("#_autoRefreshTokenTick()", "no session");
              return;
            }
            let n = Math.floor((s.expires_at * 1e3 - e) / te);
            this._debug("#_autoRefreshTokenTick()", "access token expires in ".concat(n, " ticks, a tick lasts ").concat(te, "ms, refresh threshold is ").concat($e, " ticks")), n <= $e && await this._callRefreshToken(s.refresh_token);
          });
        } catch (r) {
          console.error("Auto refresh tick failed with error. This is likely a transient error.", r);
        }
      } finally {
        this._debug("#_autoRefreshTokenTick()", "end");
      }
    }
    async _handleVisibilityChange() {
      if (this._debug("#_handleVisibilityChange()"), !$() || !(window != null && window.addEventListener)) return this.autoRefreshToken && this.startAutoRefresh(), false;
      try {
        this.visibilityChangedCallback = async () => {
          try {
            await this._onVisibilityChanged(false);
          } catch (e) {
            this._debug("#visibilityChangedCallback", "error", e);
          }
        }, window == null || window.addEventListener("visibilitychange", this.visibilityChangedCallback), await this._onVisibilityChanged(true);
      } catch (e) {
        console.error("_handleVisibilityChange", e);
      }
    }
    async _onVisibilityChanged(e) {
      let r = "#_onVisibilityChanged(".concat(e, ")");
      if (this._debug(r, "visibilityState", document.visibilityState), document.visibilityState === "visible") {
        if (this.autoRefreshToken && this._startAutoRefresh(), !e) if (await this.initializePromise, this.lock != null) await this._acquireLock(this.lockAcquireTimeout, async () => {
          if (document.visibilityState !== "visible") {
            this._debug(r, "acquired the lock to recover the session, but the browser visibilityState is no longer visible, aborting");
            return;
          }
          await this._recoverAndRefresh();
        });
        else {
          if (document.visibilityState !== "visible") {
            this._debug(r, "visibilityState is no longer visible, skipping recovery");
            return;
          }
          await this._recoverAndRefresh();
        }
      } else document.visibilityState === "hidden" && this.autoRefreshToken && this._stopAutoRefresh();
    }
    async _getUrlForProvider(e, r, s) {
      let n = s == null ? void 0 : s.redirectTo, i = null, a = null, o = null;
      this.flowType === "pkce" && ([i, a, o] = await this._getCodeChallengeAndMethod(), n = this._maybeAppendFlowIdToRedirect(n, o));
      let l = ["provider=".concat(encodeURIComponent(r))];
      if (n && l.push("redirect_to=".concat(encodeURIComponent(n))), s != null && s.scopes && l.push("scopes=".concat(encodeURIComponent(s.scopes))), i != null && a != null) {
        let u = new URLSearchParams({ code_challenge: "".concat(encodeURIComponent(i)), code_challenge_method: "".concat(encodeURIComponent(a)) });
        l.push(u.toString());
      }
      if (s != null && s.queryParams) {
        let u = new URLSearchParams(s.queryParams);
        l.push(u.toString());
      }
      return s != null && s.skipBrowserRedirect && l.push("skip_http_redirect=".concat(s.skipBrowserRedirect)), { url: "".concat(e, "?").concat(l.join("&")), flowId: o };
    }
    _maybeAppendFlowIdToRedirect(e, r) {
      return !e || !r || !this.experimental.appendPkceFlowIdToRedirects ? e != null ? e : void 0 : Ia(e, r);
    }
    async _getCodeChallengeAndMethod(e = false) {
      return ja(this.storage, this.storageKey, e, (r) => this._debug("#_getCodeChallengeAndMethod()", "evicted oldest pending PKCE verifier slot", r));
    }
    async _unenroll(e) {
      try {
        return await this._useSession(async (r) => {
          var s;
          let { data: n, error: i } = r;
          return i ? this._returnResult({ data: null, error: i }) : await b(this.fetch, "DELETE", "".concat(this.url, "/factors/").concat(e.factorId), { headers: this.headers, jwt: (s = n == null ? void 0 : n.session) === null || s === void 0 ? void 0 : s.access_token });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _enroll(e) {
      try {
        return await this._useSession(async (r) => {
          var s, n;
          let { data: i, error: a } = r;
          if (a) return this._returnResult({ data: null, error: a });
          let o = Object.assign({ friendly_name: e.friendlyName, factor_type: e.factorType }, e.factorType === "phone" ? { phone: e.phone } : e.factorType === "totp" ? { issuer: e.issuer } : {}), { data: l, error: u } = await b(this.fetch, "POST", "".concat(this.url, "/factors"), { body: o, headers: this.headers, jwt: (s = i == null ? void 0 : i.session) === null || s === void 0 ? void 0 : s.access_token });
          return u ? this._returnResult({ data: null, error: u }) : (e.factorType === "totp" && l.type === "totp" && !((n = l == null ? void 0 : l.totp) === null || n === void 0) && n.qr_code && (l.totp.qr_code = "data:image/svg+xml;utf-8,".concat(l.totp.qr_code)), this._returnResult({ data: l, error: null }));
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _verify(e) {
      let r = async () => {
        try {
          return await this._useSession(async (s) => {
            var n;
            let { data: i, error: a } = s;
            if (a) return this._returnResult({ data: null, error: a });
            let o = Object.assign({ challenge_id: e.challengeId }, "webauthn" in e ? { webauthn: Object.assign(Object.assign({}, e.webauthn), { credential_response: e.webauthn.type === "create" ? Jr(e.webauthn.credential_response) : Vr(e.webauthn.credential_response) }) } : { code: e.code }), { data: l, error: u } = await b(this.fetch, "POST", "".concat(this.url, "/factors/").concat(e.factorId, "/verify"), { body: o, headers: this.headers, jwt: (n = i == null ? void 0 : i.session) === null || n === void 0 ? void 0 : n.access_token });
            return u ? this._returnResult({ data: null, error: u }) : (await this._saveSession(Object.assign({ expires_at: Math.round(Date.now() / 1e3) + l.expires_in }, l)), await this._notifyAllSubscribers("MFA_CHALLENGE_VERIFIED", l), this._returnResult({ data: l, error: u }));
          });
        } catch (s) {
          if (w(s)) return this._returnResult({ data: null, error: s });
          throw s;
        }
      };
      return this.lock != null ? this._acquireLock(this.lockAcquireTimeout, r) : r();
    }
    async _challenge(e) {
      let r = async () => {
        try {
          return await this._useSession(async (s) => {
            var n;
            let { data: i, error: a } = s;
            if (a) return this._returnResult({ data: null, error: a });
            let o = await b(this.fetch, "POST", "".concat(this.url, "/factors/").concat(e.factorId, "/challenge"), { body: e, headers: this.headers, jwt: (n = i == null ? void 0 : i.session) === null || n === void 0 ? void 0 : n.access_token });
            if (o.error) return o;
            let { data: l } = o;
            if (l.type !== "webauthn") return { data: l, error: null };
            switch (l.webauthn.type) {
              case "create":
                return { data: Object.assign(Object.assign({}, l), { webauthn: Object.assign(Object.assign({}, l.webauthn), { credential_options: Object.assign(Object.assign({}, l.webauthn.credential_options), { publicKey: Kr(l.webauthn.credential_options.publicKey) }) }) }), error: null };
              case "request":
                return { data: Object.assign(Object.assign({}, l), { webauthn: Object.assign(Object.assign({}, l.webauthn), { credential_options: Object.assign(Object.assign({}, l.webauthn.credential_options), { publicKey: Gr(l.webauthn.credential_options.publicKey) }) }) }), error: null };
            }
          });
        } catch (s) {
          if (w(s)) return this._returnResult({ data: null, error: s });
          throw s;
        }
      };
      return this.lock != null ? this._acquireLock(this.lockAcquireTimeout, r) : r();
    }
    async _challengeAndVerify(e) {
      let { data: r, error: s } = await this._challenge({ factorId: e.factorId });
      return s ? this._returnResult({ data: null, error: s }) : await this._verify({ factorId: e.factorId, challengeId: r.id, code: e.code });
    }
    async _listFactors() {
      var e;
      let { data: { user: r }, error: s } = await this.getUser();
      if (s) return { data: null, error: s };
      let n = { all: [], phone: [], totp: [], webauthn: [], recovery_code: [] };
      for (let i of (e = r == null ? void 0 : r.factors) !== null && e !== void 0 ? e : []) n.all.push(i), i.status === "verified" && i.factor_type in n && Array.isArray(n[i.factor_type]) && n[i.factor_type].push(i);
      return { data: n, error: null };
    }
    async _getAuthenticatorAssuranceLevel(e) {
      var r, s, n, i;
      if (e) try {
        let { payload: f } = Ze(e), d = null;
        f.aal && (d = f.aal);
        let m = d, { data: { user: g }, error: y } = await this.getUser(e);
        if (y) return this._returnResult({ data: null, error: y });
        ((s = (r = g == null ? void 0 : g.factors) === null || r === void 0 ? void 0 : r.filter((k) => k.status === "verified")) !== null && s !== void 0 ? s : []).length > 0 && (m = "aal2");
        let E = f.amr || [];
        return { data: { currentLevel: d, nextLevel: m, currentAuthenticationMethods: E }, error: null };
      } catch (f) {
        if (w(f)) return this._returnResult({ data: null, error: f });
        throw f;
      }
      let { data: { session: a }, error: o } = await this.getSession();
      if (o) return this._returnResult({ data: null, error: o });
      if (!a) return { data: { currentLevel: null, nextLevel: null, currentAuthenticationMethods: [] }, error: null };
      let { payload: l } = Ze(a.access_token), u = null;
      l.aal && (u = l.aal);
      let h = u;
      ((i = (n = a.user.factors) === null || n === void 0 ? void 0 : n.filter((f) => f.status === "verified")) !== null && i !== void 0 ? i : []).length > 0 && (h = "aal2");
      let c = l.amr || [];
      return { data: { currentLevel: u, nextLevel: h, currentAuthenticationMethods: c }, error: null };
    }
    async _getRecoveryCodesStatus() {
      Pe(this.experimental);
      try {
        return await this._useSession(async (e) => {
          var r;
          let { data: s, error: n } = e;
          if (n) return this._returnResult({ data: null, error: n });
          let { data: i, error: a } = await b(this.fetch, "GET", "".concat(this.url, "/factors/recovery-codes"), { headers: this.headers, jwt: (r = s == null ? void 0 : s.session) === null || r === void 0 ? void 0 : r.access_token });
          return a ? this._returnResult({ data: null, error: a }) : this._returnResult({ data: i, error: null });
        });
      } catch (e) {
        if (w(e)) return this._returnResult({ data: null, error: e });
        throw e;
      }
    }
    async _generateRecoveryCodes(e) {
      Pe(this.experimental);
      try {
        return await this._useSession(async (r) => {
          var s;
          let { data: n, error: i } = r;
          if (i) return this._returnResult({ data: null, error: i });
          let { data: a, error: o } = await b(this.fetch, "POST", "".concat(this.url, "/factors/recovery-codes"), { body: e != null && e.friendlyName ? { friendly_name: e.friendlyName } : void 0, headers: this.headers, jwt: (s = n == null ? void 0 : n.session) === null || s === void 0 ? void 0 : s.access_token });
          return o ? this._returnResult({ data: null, error: o }) : this._returnResult({ data: a, error: null });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _verifyRecoveryCode(e) {
      Pe(this.experimental);
      let r = async () => {
        try {
          return await this._useSession(async (s) => {
            var n;
            let { data: i, error: a } = s;
            if (a) return this._returnResult({ data: null, error: a });
            let { data: o, error: l } = await b(this.fetch, "POST", "".concat(this.url, "/factors/recovery-codes/verify"), { body: { code: e.code }, headers: this.headers, jwt: (n = i == null ? void 0 : i.session) === null || n === void 0 ? void 0 : n.access_token });
            if (l) return this._returnResult({ data: null, error: l });
            let u = Object.assign({ expires_at: vs(o.expires_in) }, o);
            return await this._saveSession(u), await this._notifyAllSubscribers("MFA_CHALLENGE_VERIFIED", u), this._returnResult({ data: o, error: null });
          });
        } catch (s) {
          if (w(s)) return this._returnResult({ data: null, error: s });
          throw s;
        }
      };
      return this.lock != null ? this._acquireLock(this.lockAcquireTimeout, r) : r();
    }
    async _regenerateRecoveryCodes() {
      Pe(this.experimental);
      try {
        return await this._useSession(async (e) => {
          var r;
          let { data: s, error: n } = e;
          if (n) return this._returnResult({ data: null, error: n });
          let { data: i, error: a } = await b(this.fetch, "POST", "".concat(this.url, "/factors/recovery-codes/regenerate"), { headers: this.headers, jwt: (r = s == null ? void 0 : s.session) === null || r === void 0 ? void 0 : r.access_token });
          return a ? this._returnResult({ data: null, error: a }) : this._returnResult({ data: i, error: null });
        });
      } catch (e) {
        if (w(e)) return this._returnResult({ data: null, error: e });
        throw e;
      }
    }
    async _unenrollRecoveryCodes() {
      Pe(this.experimental);
      try {
        return await this._useSession(async (e) => {
          var r;
          let { data: s, error: n } = e;
          if (n) return this._returnResult({ data: null, error: n });
          let { data: i, error: a } = await b(this.fetch, "DELETE", "".concat(this.url, "/factors/recovery-codes"), { headers: this.headers, jwt: (r = s == null ? void 0 : s.session) === null || r === void 0 ? void 0 : r.access_token });
          return a ? this._returnResult({ data: null, error: a }) : this._returnResult({ data: i, error: null });
        });
      } catch (e) {
        if (w(e)) return this._returnResult({ data: null, error: e });
        throw e;
      }
    }
    async _getAuthorizationDetails(e) {
      try {
        return await this._useSession(async (r) => {
          let { data: { session: s }, error: n } = r;
          return n ? this._returnResult({ data: null, error: n }) : s ? await b(this.fetch, "GET", "".concat(this.url, "/oauth/authorizations/").concat(e), { headers: this.headers, jwt: s.access_token, xform: (i) => ({ data: i, error: null }) }) : this._returnResult({ data: null, error: new C() });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _approveAuthorization(e, r) {
      try {
        return await this._useSession(async (s) => {
          let { data: { session: n }, error: i } = s;
          if (i) return this._returnResult({ data: null, error: i });
          if (!n) return this._returnResult({ data: null, error: new C() });
          let a = await b(this.fetch, "POST", "".concat(this.url, "/oauth/authorizations/").concat(e, "/consent"), { headers: this.headers, jwt: n.access_token, body: { action: "approve" }, xform: (o) => ({ data: o, error: null }) });
          return a.data && a.data.redirect_url && $() && !(r != null && r.skipBrowserRedirect) && window.location.assign(a.data.redirect_url), a;
        });
      } catch (s) {
        if (w(s)) return this._returnResult({ data: null, error: s });
        throw s;
      }
    }
    async _denyAuthorization(e, r) {
      try {
        return await this._useSession(async (s) => {
          let { data: { session: n }, error: i } = s;
          if (i) return this._returnResult({ data: null, error: i });
          if (!n) return this._returnResult({ data: null, error: new C() });
          let a = await b(this.fetch, "POST", "".concat(this.url, "/oauth/authorizations/").concat(e, "/consent"), { headers: this.headers, jwt: n.access_token, body: { action: "deny" }, xform: (o) => ({ data: o, error: null }) });
          return a.data && a.data.redirect_url && $() && !(r != null && r.skipBrowserRedirect) && window.location.assign(a.data.redirect_url), a;
        });
      } catch (s) {
        if (w(s)) return this._returnResult({ data: null, error: s });
        throw s;
      }
    }
    async _listOAuthGrants() {
      try {
        return await this._useSession(async (e) => {
          let { data: { session: r }, error: s } = e;
          return s ? this._returnResult({ data: null, error: s }) : r ? await b(this.fetch, "GET", "".concat(this.url, "/user/oauth/grants"), { headers: this.headers, jwt: r.access_token, xform: (n) => ({ data: n, error: null }) }) : this._returnResult({ data: null, error: new C() });
        });
      } catch (e) {
        if (w(e)) return this._returnResult({ data: null, error: e });
        throw e;
      }
    }
    async _revokeOAuthGrant(e) {
      try {
        return await this._useSession(async (r) => {
          let { data: { session: s }, error: n } = r;
          return n ? this._returnResult({ data: null, error: n }) : s ? (await b(this.fetch, "DELETE", "".concat(this.url, "/user/oauth/grants"), { headers: this.headers, jwt: s.access_token, query: { client_id: e.clientId }, noResolveJson: true }), { data: {}, error: null }) : this._returnResult({ data: null, error: new C() });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async fetchJwk(e, r = { keys: [] }) {
      let s = r.keys.find((o) => o.kid === e);
      if (s) return s;
      let n = Date.now();
      if (s = this.jwks.keys.find((o) => o.kid === e), s && this.jwks_cached_at + la > n) return s;
      let { data: i, error: a } = await b(this.fetch, "GET", "".concat(this.url, "/.well-known/jwks.json"), { headers: this.headers });
      if (a) throw a;
      return !i.keys || i.keys.length === 0 || (this.jwks = i, this.jwks_cached_at = n, s = i.keys.find((o) => o.kid === e), !s) ? null : s;
    }
    async getClaims(e, r = {}) {
      try {
        let s = e;
        if (!s) {
          let { data: f, error: d } = await this.getSession();
          if (d || !f.session) return this._returnResult({ data: null, error: d });
          s = f.session.access_token;
        }
        let { header: n, payload: i, signature: a, raw: { header: o, payload: l } } = Ze(s);
        if (!(r != null && r.allowExpired)) try {
          $a(i.exp);
        } catch (f) {
          throw new ot(f instanceof Error ? f.message : "JWT validation failed");
        }
        let u = !n.alg || n.alg.startsWith("HS") || !n.kid || !("crypto" in globalThis && "subtle" in globalThis.crypto) ? null : await this.fetchJwk(n.kid, r != null && r.keys ? { keys: r.keys } : r == null ? void 0 : r.jwks);
        if (!u) {
          let { error: f } = await this.getUser(s);
          if (f) throw f;
          return { data: { claims: i, header: n, signature: a }, error: null };
        }
        let h = Na(n.alg), c = await crypto.subtle.importKey("jwk", u, h, true, ["verify"]);
        if (!await crypto.subtle.verify(h, c, a, ya("".concat(o, ".").concat(l)))) throw new ot("Invalid JWT signature");
        return { data: { claims: i, header: n, signature: a }, error: null };
      } catch (s) {
        if (w(s)) return this._returnResult({ data: null, error: s });
        throw s;
      }
    }
    async signInWithPasskey(e) {
      var r, s, n, i;
      try {
        if (!ht()) return this._returnResult({ data: null, error: new H("Browser does not support WebAuthn", null) });
        let { data: a, error: o } = await this._startPasskeyAuthentication({ options: { captchaToken: (r = e == null ? void 0 : e.options) === null || r === void 0 ? void 0 : r.captchaToken } });
        if (o || !a) return this._returnResult({ data: null, error: o });
        let l = Gr(a.options), u = (n = (s = e == null ? void 0 : e.options) === null || s === void 0 ? void 0 : s.signal) !== null && n !== void 0 ? n : Mt.createNewAbortSignal(), { data: h, error: c } = await js({ publicKey: l, signal: u, mediation: (i = e == null ? void 0 : e.options) === null || i === void 0 ? void 0 : i.mediation });
        if (c || !h) return this._returnResult({ data: null, error: c != null ? c : new H("WebAuthn ceremony failed", null) });
        let f = Vr(h);
        return this._verifyPasskeyAuthentication({ challengeId: a.challenge_id, credential: f });
      } catch (a) {
        if (w(a)) return this._returnResult({ data: null, error: a });
        throw a;
      }
    }
    async registerPasskey(e) {
      var r, s;
      try {
        if (!ht()) return this._returnResult({ data: null, error: new H("Browser does not support WebAuthn", null) });
        let { data: n, error: i } = await this._startPasskeyRegistration();
        if (i || !n) return this._returnResult({ data: null, error: i });
        let a = Kr(n.options), o = (s = (r = e == null ? void 0 : e.options) === null || r === void 0 ? void 0 : r.signal) !== null && s !== void 0 ? s : Mt.createNewAbortSignal(), { data: l, error: u } = await Is({ publicKey: a, signal: o });
        if (u || !l) return this._returnResult({ data: null, error: u != null ? u : new H("WebAuthn ceremony failed", null) });
        let h = Jr(l);
        return this._verifyPasskeyRegistration({ challengeId: n.challenge_id, credential: h });
      } catch (n) {
        if (w(n)) return this._returnResult({ data: null, error: n });
        throw n;
      }
    }
    async _startPasskeyRegistration() {
      try {
        return await this._useSession(async (e) => {
          let { data: { session: r }, error: s } = e;
          if (s) return this._returnResult({ data: null, error: s });
          if (!r) return this._returnResult({ data: null, error: new C() });
          let { data: n, error: i } = await b(this.fetch, "POST", "".concat(this.url, "/passkeys/registration/options"), { headers: this.headers, jwt: r.access_token, body: {} });
          return i ? this._returnResult({ data: null, error: i }) : this._returnResult({ data: n, error: null });
        });
      } catch (e) {
        if (w(e)) return this._returnResult({ data: null, error: e });
        throw e;
      }
    }
    async _verifyPasskeyRegistration(e) {
      try {
        return await this._useSession(async (r) => {
          let { data: { session: s }, error: n } = r;
          if (n) return this._returnResult({ data: null, error: n });
          if (!s) return this._returnResult({ data: null, error: new C() });
          let { data: i, error: a } = await b(this.fetch, "POST", "".concat(this.url, "/passkeys/registration/verify"), { headers: this.headers, jwt: s.access_token, body: { challenge_id: e.challengeId, credential: e.credential } });
          return a ? this._returnResult({ data: null, error: a }) : this._returnResult({ data: i, error: null });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _startPasskeyAuthentication(e) {
      var r;
      try {
        let { data: s, error: n } = await b(this.fetch, "POST", "".concat(this.url, "/passkeys/authentication/options"), { headers: this.headers, body: { gotrue_meta_security: { captcha_token: (r = e == null ? void 0 : e.options) === null || r === void 0 ? void 0 : r.captchaToken } } });
        return n ? this._returnResult({ data: null, error: n }) : this._returnResult({ data: s, error: null });
      } catch (s) {
        if (w(s)) return this._returnResult({ data: null, error: s });
        throw s;
      }
    }
    async _verifyPasskeyAuthentication(e) {
      try {
        let { data: r, error: s } = await b(this.fetch, "POST", "".concat(this.url, "/passkeys/authentication/verify"), { headers: this.headers, body: { challenge_id: e.challengeId, credential: e.credential }, xform: q });
        return s ? this._returnResult({ data: null, error: s }) : (r.session && (await this._saveSession(r.session), await this._notifyAllSubscribers("SIGNED_IN", r.session)), this._returnResult({ data: r, error: null }));
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _listPasskeys() {
      try {
        return await this._useSession(async (e) => {
          let { data: { session: r }, error: s } = e;
          if (s) return this._returnResult({ data: null, error: s });
          if (!r) return this._returnResult({ data: null, error: new C() });
          let { data: n, error: i } = await b(this.fetch, "GET", "".concat(this.url, "/passkeys"), { headers: this.headers, jwt: r.access_token, xform: (a) => ({ data: a, error: null }) });
          return i ? this._returnResult({ data: null, error: i }) : this._returnResult({ data: n, error: null });
        });
      } catch (e) {
        if (w(e)) return this._returnResult({ data: null, error: e });
        throw e;
      }
    }
    async _updatePasskey(e) {
      try {
        return await this._useSession(async (r) => {
          let { data: { session: s }, error: n } = r;
          if (n) return this._returnResult({ data: null, error: n });
          if (!s) return this._returnResult({ data: null, error: new C() });
          let { data: i, error: a } = await b(this.fetch, "PATCH", "".concat(this.url, "/passkeys/").concat(e.passkeyId), { headers: this.headers, jwt: s.access_token, body: { friendly_name: e.friendlyName } });
          return a ? this._returnResult({ data: null, error: a }) : this._returnResult({ data: i, error: null });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
    async _deletePasskey(e) {
      try {
        return await this._useSession(async (r) => {
          let { data: { session: s }, error: n } = r;
          if (n) return this._returnResult({ data: null, error: n });
          if (!s) return this._returnResult({ data: null, error: new C() });
          let { error: i } = await b(this.fetch, "DELETE", "".concat(this.url, "/passkeys/").concat(e.passkeyId), { headers: this.headers, jwt: s.access_token, noResolveJson: true });
          return i ? this._returnResult({ data: null, error: i }) : this._returnResult({ data: null, error: null });
        });
      } catch (r) {
        if (w(r)) return this._returnResult({ data: null, error: r });
        throw r;
      }
    }
  };
  Ps.nextInstanceID = {};
  var ro = Ps;
  var no = ro;
  var io = no;
  var ao = "2.118.0";
  var Ne = "";
  var dt;
  if (typeof Deno != "undefined") Ne = "deno", dt = (jt = Deno.version) === null || jt === void 0 ? void 0 : jt.deno;
  else if (typeof document != "undefined") Ne = "web";
  else if (typeof navigator != "undefined" && navigator.product === "ReactNative") Ne = "react-native";
  else {
    Ne = "node";
    let t = globalThis.process;
    dt = t == null || (Pt = t.version) === null || Pt === void 0 ? void 0 : Pt.replace(/^v/, "");
  }
  var jt;
  var Pt;
  var Cs = ["runtime=".concat(Ne)];
  dt && Cs.push("runtime-version=".concat(dt));
  var oo = { "X-Client-Info": "supabase-js/".concat(ao, "; ").concat(Cs.join("; ")) };
  var lo = { headers: oo };
  var uo = { schema: "public" };
  var ho = { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true, flowType: "implicit" };
  var co = {};
  var fo = { enabled: false, respectSamplingDecision: true };
  function po(t) {
    if (!t || typeof t != "string") return null;
    let e = t.split("-");
    if (e.length !== 4) return null;
    let [r, s, n, i] = e;
    if (r.length !== 2 || s.length !== 32 || n.length !== 16 || i.length !== 2) return null;
    let a = /^[0-9a-f]+$/i;
    return !a.test(r) || !a.test(s) || !a.test(n) || !a.test(i) || s === "00000000000000000000000000000000" || n === "0000000000000000" ? null : { version: r, traceId: s, parentId: n, traceFlags: i, isSampled: (parseInt(i, 16) & 1) === 1 };
  }
  function go(t, e) {
    if (!t || !e || e.length === 0) return false;
    let r;
    if (t instanceof URL) r = t;
    else try {
      r = new URL(t);
    } catch (s) {
      return false;
    }
    for (let s of e) try {
      if (typeof s == "string") {
        if (yo(r.hostname, s)) return true;
      } else if (s instanceof RegExp) {
        if (s.test(r.hostname)) return true;
      } else if (typeof s == "function" && s(r)) return true;
    } catch (n) {
      continue;
    }
    return false;
  }
  function yo(t, e) {
    if (e === t) return true;
    if (e.startsWith("*.")) {
      let r = e.slice(2);
      if (t.endsWith(r) && (t === r || t.endsWith("." + r))) return true;
    }
    return false;
  }
  function mo(t) {
    let e = [];
    try {
      let r = new URL(t);
      e.push(r.hostname);
    } catch (r) {
    }
    return e.push("*.supabase.co", "*.supabase.in"), e.push("localhost", "127.0.0.1", "[::1]"), e;
  }
  function Me(t) {
    "@babel/helpers - typeof";
    return Me = typeof Symbol == "function" && typeof Symbol.iterator == "symbol" ? function(e) {
      return typeof e;
    } : function(e) {
      return e && typeof Symbol == "function" && e.constructor === Symbol && e !== Symbol.prototype ? "symbol" : typeof e;
    }, Me(t);
  }
  function wo(t, e) {
    if (Me(t) != "object" || !t) return t;
    var r = t[Symbol.toPrimitive];
    if (r !== void 0) {
      var s = r.call(t, e || "default");
      if (Me(s) != "object") return s;
      throw new TypeError("@@toPrimitive must return a primitive value.");
    }
    return (e === "string" ? String : Number)(t);
  }
  function bo(t) {
    var e = wo(t, "string");
    return Me(e) == "symbol" ? e : e + "";
  }
  function vo(t, e, r) {
    return (e = bo(e)) in t ? Object.defineProperty(t, e, { value: r, enumerable: true, configurable: true, writable: true }) : t[e] = r, t;
  }
  function Yr(t, e) {
    var r = Object.keys(t);
    if (Object.getOwnPropertySymbols) {
      var s = Object.getOwnPropertySymbols(t);
      e && (s = s.filter(function(n) {
        return Object.getOwnPropertyDescriptor(t, n).enumerable;
      })), r.push.apply(r, s);
    }
    return r;
  }
  function A(t) {
    for (var e = 1; e < arguments.length; e++) {
      var r = arguments[e] != null ? arguments[e] : {};
      e % 2 ? Yr(Object(r), true).forEach(function(s) {
        vo(t, s, r[s]);
      }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(t, Object.getOwnPropertyDescriptors(r)) : Yr(Object(r)).forEach(function(s) {
        Object.defineProperty(t, s, Object.getOwnPropertyDescriptor(r, s));
      });
    }
    return t;
  }
  var _o = (t) => t ? (...e) => t(...e) : (...e) => fetch(...e);
  var ko = () => Headers;
  var $s = (t) => t.startsWith("sb_publishable_") || t.startsWith("sb_secret_");
  var Eo = "sb_temp_";
  var Xr = /* @__PURE__ */ new Set();
  var So = (t) => {
    var e, r;
    if (!t.startsWith("sb_") || $s(t) || t.startsWith(Eo)) return;
    let s = (e = (r = t.match(/^sb_[a-zA-Z0-9]+_/)) === null || r === void 0 ? void 0 : r[0]) !== null && e !== void 0 ? e : "unknown";
    Xr.has(s) || (Xr.add(s), console.warn("@supabase/supabase-js: Unrecognized Supabase API key format. The client will proceed and send this key as-is; if you see authentication errors you may need to upgrade @supabase/supabase-js to a version that recognizes this key type."));
  };
  var Qr = (t, e, r, s, n, i) => {
    let a = _o(s), o = ko(), l = (n == null ? void 0 : n.enabled) === true, u = (n == null ? void 0 : n.respectSamplingDecision) !== false, h = l ? mo(e) : null, c = !(i != null && i.omitApiKeyAsBearer && $s(t));
    return async (f, d) => {
      let m = await r(), g = new o(d == null ? void 0 : d.headers);
      if (g.has("apikey") || g.set("apikey", t), !g.has("Authorization")) {
        let y = m != null ? m : c ? t : null;
        y && g.set("Authorization", "Bearer ".concat(y));
      }
      if (h) {
        let y = To(f, h, u);
        y && (y.traceparent && !g.has("traceparent") && g.set("traceparent", y.traceparent), y.tracestate && !g.has("tracestate") && g.set("tracestate", y.tracestate), y.baggage && !g.has("baggage") && g.set("baggage", y.baggage));
      }
      return a(f, A(A({}, d), {}, { headers: g }));
    };
  };
  var Zr = false;
  var es = false;
  function To(t, e, r) {
    let s = wn();
    if (!s) return Zr || (Zr = true, console.warn("@supabase/supabase-js: tracePropagation is enabled but the tracing runtime is not loaded, so trace headers will not be attached. Add `import '@supabase/supabase-js/tracing'` at your application entry point (requires the OpenTelemetry API package to be installed). The CDN/UMD build does not support trace propagation.")), null;
    if (!go(typeof t == "string" || t instanceof URL ? t : t.url, e)) return null;
    let n = s();
    if (!n || !n.traceparent) {
      var i;
      if (!(n == null || (i = n.carrierKeys) === null || i === void 0) && i.length && !es) {
        es = true;
        let a = n.carrierKeys.includes("sentry-trace") ? " Sentry detected: set `propagateTraceparent: true` in Sentry.init() to emit it." : " Configure your tracing SDK to emit W3C trace context on outgoing requests.";
        console.warn("@supabase/supabase-js: tracePropagation is enabled and a tracing SDK is active, but its propagator wrote [".concat(n.carrierKeys.join(", "), "] and no W3C traceparent header, so trace headers will not be attached.") + a);
      }
      return null;
    }
    if (r) {
      let a = po(n.traceparent);
      if (a && !a.isSampled) return { traceparent: n.traceparent };
    }
    return n;
  }
  function ts(t) {
    return typeof t == "boolean" ? { enabled: t } : t;
  }
  function Ro(t) {
    return t.endsWith("/") ? t : t + "/";
  }
  var rs = false;
  function Ao(t) {
    rs || typeof t != "object" || t === null || !("schema" in t) || t.schema === void 0 || (rs = true, console.warn('@supabase/supabase-js: The "schema" option must be nested under "db", e.g. createClient(url, key, { db: { schema: \'myschema\' } }). A top-level "schema" is ignored and queries go to the default schema.'));
  }
  function Oo(t, e) {
    var r, s, n, i, a, o;
    let { db: l, auth: u, realtime: h, global: c } = t, { db: f, auth: d, realtime: m, global: g } = e, y = ts(t.tracePropagation), E = ts(e.tracePropagation), k = { db: A(A({}, f), l), auth: A(A({}, d), u), realtime: A(A({}, m), h), storage: {}, global: A(A(A({}, g), c), {}, { headers: A(A({}, (r = g == null ? void 0 : g.headers) !== null && r !== void 0 ? r : {}), (s = c == null ? void 0 : c.headers) !== null && s !== void 0 ? s : {}) }), tracePropagation: { enabled: (n = (i = y == null ? void 0 : y.enabled) !== null && i !== void 0 ? i : E == null ? void 0 : E.enabled) !== null && n !== void 0 ? n : false, respectSamplingDecision: (a = (o = y == null ? void 0 : y.respectSamplingDecision) !== null && o !== void 0 ? o : E == null ? void 0 : E.respectSamplingDecision) !== null && a !== void 0 ? a : true }, accessToken: async () => "" };
    return t.accessToken ? k.accessToken = t.accessToken : delete k.accessToken, k;
  }
  function Io(t) {
    let e = t == null ? void 0 : t.trim();
    if (!e) throw new Error("supabaseUrl is required.");
    if (!e.match(/^https?:\/\//i)) throw new Error("Invalid supabaseUrl: Must be a valid HTTP or HTTPS URL.");
    try {
      return new URL(Ro(e));
    } catch (r) {
      throw Error("Invalid supabaseUrl: Provided URL is malformed.");
    }
  }
  var jo = class extends io {
    constructor(t) {
      super(t);
    }
  };
  var Po = class {
    constructor(t, e, r) {
      var s, n;
      this.supabaseUrl = t, this.supabaseKey = e;
      let i = Io(t);
      if (!e) throw new Error("supabaseKey is required.");
      So(e), Ao(r), this.realtimeUrl = new URL("realtime/v1", i), this.realtimeUrl.protocol = this.realtimeUrl.protocol.replace("http", "ws"), this.authUrl = new URL("auth/v1", i), this.storageUrl = new URL("storage/v1", i), this.functionsUrl = new URL("functions/v1", i);
      let a = "sb-".concat(i.hostname.split(".")[0], "-auth-token"), o = { db: uo, realtime: co, auth: A(A({}, ho), {}, { storageKey: a }), global: lo, tracePropagation: fo }, l = Oo(r != null ? r : {}, o);
      if (this.settings = l, this.storageKey = (s = l.auth.storageKey) !== null && s !== void 0 ? s : "", this.headers = (n = l.global.headers) !== null && n !== void 0 ? n : {}, l.accessToken) this.accessToken = l.accessToken, this.auth = new Proxy({}, { get: (h, c) => {
        throw new Error("@supabase/supabase-js: Supabase Client is configured with the accessToken option, accessing supabase.auth.".concat(String(c), " is not possible"));
      } });
      else {
        var u;
        this.auth = this._initSupabaseAuthClient((u = l.auth) !== null && u !== void 0 ? u : {}, this.headers, l.global.fetch);
      }
      this.fetch = Qr(e, t, this._getSessionToken.bind(this), l.global.fetch, l.tracePropagation), this.functionsFetch = Qr(e, t, this._getSessionToken.bind(this), l.global.fetch, l.tracePropagation, { omitApiKeyAsBearer: true }), this.realtime = this._initRealtimeClient(A({ headers: this.headers, accessToken: this._getAccessToken.bind(this), fetch: this.fetch }, l.realtime)), this.accessToken && Promise.resolve(this.accessToken()).then((h) => this.realtime.setAuth(h)).catch((h) => console.warn("Failed to set initial Realtime auth token:", h)), this.rest = new Cn(new URL("rest/v1", i).href, { headers: this.headers, schema: l.db.schema, fetch: this.fetch, timeout: l.db.timeout, urlLengthLimit: l.db.urlLengthLimit, retry: l.db.retry }), this.storage = new ta(this.storageUrl.href, this.headers, this.fetch, r == null ? void 0 : r.storage), l.accessToken || this._listenForAuthEvents();
    }
    get functions() {
      return new kn(this.functionsUrl.href, { headers: this.headers, customFetch: this.functionsFetch });
    }
    from(t) {
      return this.rest.from(t);
    }
    schema(t) {
      return this.rest.schema(t);
    }
    getOpenApiSpec() {
      return this.rest.getOpenApiSpec();
    }
    rpc(t, e = {}, r = { head: false, get: false, count: void 0 }) {
      return this.rest.rpc(t, e, r);
    }
    channel(t, e = { config: {} }) {
      return this.realtime.channel(t, e);
    }
    getChannels() {
      return this.realtime.getChannels();
    }
    removeChannel(t) {
      return this.realtime.removeChannel(t);
    }
    removeAllChannels() {
      return this.realtime.removeAllChannels();
    }
    async _getSessionToken() {
      var t = this, e, r;
      if (t.accessToken) return await t.accessToken();
      let { data: s } = await t.auth.getSession();
      return (e = (r = s.session) === null || r === void 0 ? void 0 : r.access_token) !== null && e !== void 0 ? e : null;
    }
    async _getAccessToken() {
      var t = this, e;
      return (e = await t._getSessionToken()) !== null && e !== void 0 ? e : t.supabaseKey;
    }
    _initSupabaseAuthClient({ autoRefreshToken: t, persistSession: e, detectSessionInUrl: r, storage: s, userStorage: n, storageKey: i, flowType: a, lock: o, debug: l, throwOnError: u, experimental: h, lockAcquireTimeout: c, skipAutoInitialize: f }, d, m) {
      let g = { Authorization: "Bearer ".concat(this.supabaseKey), apikey: "".concat(this.supabaseKey) };
      return new jo({ url: this.authUrl.href, headers: A(A({}, g), d), storageKey: i, autoRefreshToken: t, persistSession: e, detectSessionInUrl: r, storage: s, userStorage: n, flowType: a, lock: o, debug: l, throwOnError: u, experimental: h, fetch: m, lockAcquireTimeout: c, skipAutoInitialize: f, hasCustomAuthorizationHeader: Object.keys(this.headers).some((y) => y.toLowerCase() === "authorization") });
    }
    _initRealtimeClient(t) {
      return new Ti(this.realtimeUrl.href, A(A({}, t), {}, { params: A(A({}, { apikey: this.supabaseKey }), t == null ? void 0 : t.params) }));
    }
    _listenForAuthEvents() {
      return this.auth.onAuthStateChange((t, e) => {
        this._handleTokenChanged(t, "CLIENT", e == null ? void 0 : e.access_token);
      });
    }
    _handleTokenChanged(t, e, r) {
      (t === "TOKEN_REFRESHED" || t === "SIGNED_IN" || t === "INITIAL_SESSION") && this.changedAccessToken !== r ? (this.changedAccessToken = r, this.realtime.setAuth(r)) : t === "SIGNED_OUT" && (this.realtime.setAuth(), e == "STORAGE" && this.auth.signOut(), this.changedAccessToken = void 0);
    }
  };
  var Zo = (t, e, r) => new Po(t, e, r);
  function Co() {
    if (typeof window != "undefined" || globalThis.Deno !== void 0) return false;
    let t = globalThis.process;
    if (!t) return false;
    let e = t.version;
    if (e == null) return false;
    let r = e.match(/^v(\d+)\./);
    return r ? parseInt(r[1], 10) <= 20 : false;
  }
  Co() && console.warn("⚠️  Node.js 20 and below are deprecated and will no longer be supported in future versions of @supabase/supabase-js. Please upgrade to Node.js 22 or later. For more information, visit: https://github.com/orgs/supabase/discussions/45715");
  /*! Bundled license information:
  
  unenv/dist/runtime/node/internal/buffer/ieee754.mjs:
    (*! ieee754. BSD-3-Clause License. Feross Aboukhadijeh <https://feross.org/opensource> *)
  
  unenv/dist/runtime/node/internal/buffer/buffer.mjs:
    (*!
    * The buffer module from node.js, for the browser.
    *
    * @author   Feross Aboukhadijeh <https://feross.org>
    * @license  MIT
    *)
  */

  // secure-files.js
  function privateStoragePath(value, projectUrl) {
    try {
      const url = new URL(value);
      if (url.origin !== new URL(projectUrl).origin) return null;
      const match = url.pathname.match(/^\/storage\/v1\/object\/public\/(daily-instructions|technical-job-files|shift-documents)\/(.+)$/);
      return match ? { bucket: match[1], path: decodeURIComponent(match[2]) } : null;
    } catch (e) {
      return null;
    }
  }
  function installPrivateFileLinks(client, projectUrl) {
    const cache = /* @__PURE__ */ new Map();
    const inFlight = /* @__PURE__ */ new WeakMap();
    const sourceUrls = /* @__PURE__ */ new WeakMap();
    const attributes = { A: "href", IMG: "src", IFRAME: "src", OBJECT: "data", SOURCE: "src", VIDEO: "src" };
    async function authorize(element) {
      const attribute = attributes[element.tagName];
      if (!attribute) return;
      const original = element.getAttribute(attribute);
      const originalFile = privateStoragePath(original, projectUrl);
      if (originalFile) sourceUrls.set(element, { original, displayed: original });
      const previous = sourceUrls.get(element);
      const file = originalFile || ((previous == null ? void 0 : previous.displayed) === original ? privateStoragePath(previous.original, projectUrl) : null);
      if (!file || inFlight.get(element) === original) return;
      inFlight.set(element, original);
      try {
        const key = "".concat(file.bucket, "/").concat(file.path);
        let entry = cache.get(key);
        if (!entry || entry.until < Date.now()) {
          const { data, error } = await client.storage.from(file.bucket).createSignedUrl(file.path, 600);
          if (error || !(data == null ? void 0 : data.signedUrl)) return;
          entry = { url: data.signedUrl, until: Date.now() + 3e5 };
          cache.set(key, entry);
        }
        if (element.getAttribute(attribute) === original && original !== entry.url) {
          sourceUrls.set(element, { original: (previous == null ? void 0 : previous.original) || original, displayed: entry.url });
          element.setAttribute(attribute, entry.url);
        }
      } finally {
        inFlight.delete(element);
      }
    }
    function scan(root) {
      if (root.nodeType !== 1) return;
      authorize(root);
      root.querySelectorAll("a[href],img[src],iframe[src],object[data],source[src],video[src]").forEach(authorize);
    }
    const observer = new MutationObserver((records) => {
      for (const record of records) {
        if (record.type === "attributes") authorize(record.target);
        else record.addedNodes.forEach(scan);
      }
    });
    observer.observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ["href", "src", "data"] });
    scan(document.documentElement);
    window.setInterval(() => scan(document.documentElement), 24e4);
    return observer;
  }

  // offline-queue.js?v=20261021-stock-visit-integrity-v1
  async function processOfflineQueueInOrder(queue, send) {
    const items = Array.isArray(queue) ? queue : [];
    let synced = 0;
    for (let index = 0; index < items.length; index += 1) {
      let ok = false;
      try {
        ok = await send(items[index]);
      } catch (_) {
        ok = false;
      }
      if (!ok) return { remaining: items.slice(index), synced };
      synced += 1;
    }
    return { remaining: [], synced };
  }

  // supabase-zebra.js?zebra=20261102-v4
  var supabaseUrl = "https://rerjlkrhiytgscjerqgs.supabase.co";
  var supabaseAnonKey = "sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S";
  var OFFLINE_QUEUE_KEY = "olvendOfflineRequestQueueV1";
  function readOfflineQueue() {
    try {
      return JSON.parse(localStorage.getItem(OFFLINE_QUEUE_KEY) || "[]");
    } catch (_) {
      return [];
    }
  }
  function writeOfflineQueue(queue) {
    localStorage.setItem(OFFLINE_QUEUE_KEY, JSON.stringify(queue));
    window.dispatchEvent(new CustomEvent("olvend-offline-queue", { detail: { pending: queue.length } }));
  }
  function canQueueRequest(url, init) {
    const method = String((init == null ? void 0 : init.method) || "GET").toUpperCase();
    if (method === "PATCH" || method === "DELETE") return true;
    if (method !== "POST") return false;
    const prefer = new Headers((init == null ? void 0 : init.headers) || {}).get("prefer") || "";
    return new URL(String(url), window.location.href).searchParams.has("on_conflict") && !prefer.includes("return=representation");
  }
  async function offlineAwareFetch(input, init = {}) {
    const request = input instanceof Request ? input : null;
    const url = (request == null ? void 0 : request.url) || String(input);
    const requestInit = {
      method: init.method || (request == null ? void 0 : request.method) || "GET",
      headers: init.headers || (request == null ? void 0 : request.headers),
      body: init.body
    };
    const queueable = canQueueRequest(url, requestInit);
    const method = String(requestInit.method || "GET").toUpperCase();
    const maxAttempts = !queueable && (method === "GET" || method === "HEAD") && !init.signal ? 2 : 1;
    let lastError = null;
    for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
      const controller = typeof AbortController === "function" ? new AbortController() : null;
      const timeoutMs = queueable ? 3e3 : attempt === 0 ? 18e3 : 25e3;
      let timer = null;
      try {
        const requestInit2 = controller ? __spreadProps(__spreadValues({}, init), { signal: init.signal || controller.signal }) : init;
        const requestPromise = fetch(input, requestInit2);
        const timeoutPromise = new Promise((_, reject) => {
          timer = window.setTimeout(() => {
            if (controller) controller.abort();
            const timeoutError = new Error("Request aborted by timeout");
            timeoutError.name = "AbortError";
            reject(timeoutError);
          }, timeoutMs);
        });
        return await Promise.race([requestPromise, timeoutPromise]);
      } catch (error) {
        lastError = error;
        const wasAborted = (error == null ? void 0 : error.name) === "AbortError" || /abort/i.test(String((error == null ? void 0 : error.message) || error || ""));
        if (attempt + 1 < maxAttempts && wasAborted) {
          await new Promise((resolve) => window.setTimeout(resolve, 400));
          continue;
        }
        break;
      } finally {
        if (timer !== null) window.clearTimeout(timer);
      }
    }
    if (queueable) {
      const queue = readOfflineQueue();
      queue.push({
        id: crypto.randomUUID(),
        url,
        method: requestInit.method,
        headers: Object.fromEntries(new Headers(requestInit.headers || {}).entries()),
        body: requestInit.body || null,
        queuedAt: (/* @__PURE__ */ new Date()).toISOString()
      });
      writeOfflineQueue(queue);
      return new Response("", {
        status: String(requestInit.method).toUpperCase() === "DELETE" ? 204 : 201,
        headers: { "content-type": "application/json", "x-olvend-offline": "queued" }
      });
    }
    throw lastError;
  }
  async function syncOfflineRequests() {
    var _a2;
    if (!navigator.onLine) return { pending: readOfflineQueue().length, synced: 0 };
    const queue = readOfflineQueue();
    let accessToken = null;
    try {
      const { data } = await supabase.auth.getSession();
      accessToken = ((_a2 = data == null ? void 0 : data.session) == null ? void 0 : _a2.access_token) || null;
    } catch (_) {
    }
    const result = await processOfflineQueueInOrder(queue, async (item) => {
      const headers = new Headers(item.headers || {});
      if (accessToken) headers.set("authorization", "Bearer ".concat(accessToken));
      headers.delete("content-length");
      const response = await fetch(item.url, { method: item.method, headers, body: item.body });
      return response.ok;
    });
    writeOfflineQueue(result.remaining);
    return { pending: result.remaining.length, synced: result.synced };
  }
  function getOfflineRequestCount() {
    return readOfflineQueue().length;
  }
  var supabase = Zo(supabaseUrl, supabaseAnonKey, {
    global: { fetch: offlineAwareFetch }
  });
  function withStartupTimeout(promise, timeoutMs, message) {
    return Promise.race([
      promise,
      new Promise((_, reject) => window.setTimeout(() => reject(new Error(message)), timeoutMs))
    ]);
  }
  async function ensureWarehouseSession() {
    let sessionResult;
    try {
      sessionResult = await withStartupTimeout(
        supabase.auth.getSession(),
        8e3,
        "Ověření uloženého přihlášení trvalo příliš dlouho. Přihlas se prosím znovu."
      );
    } catch (error) {
      localStorage.removeItem("sb-rerjlkrhiytgscjerqgs-auth-token");
      window.location.replace("zebra-prihlaseni.html");
      throw error;
    }
    const session = sessionResult && sessionResult.data && sessionResult.data.session;
    if (!session) {
      window.location.replace("zebra-prihlaseni.html");
      throw new Error("Přihlášení vypršelo. Přihlas se prosím znovu.");
    }
    if (typeof navigator === "undefined" || navigator.onLine !== false) {
      const activeResult = await withStartupTimeout(
        supabase.rpc("security_active_employee"),
        1e4,
        "Server nepotvrdil přihlášení včas. Zkontroluj připojení a zkus to znovu."
      );
      if (activeResult.error || activeResult.data !== true) {
        if (!activeResult.error || activeResult.error.code === "42501") await supabase.auth.signOut({ scope: "local" });
        if (!activeResult.error || activeResult.error.code === "42501") window.location.replace("zebra-prihlaseni.html");
        throw activeResult.error || new Error("Přístup vyžaduje aktivní zaměstnanecký účet.");
      }
    }
    return session;
  }
  installPrivateFileLinks(supabase, supabaseUrl);
  window.setTimeout(() => syncOfflineRequests(), 0);

  // warehouse-picking-core.mjs
  function normalizeText(value) {
    return String(value != null ? value : "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim();
  }
  function escapeHtml(value) {
    return String(value != null ? value : "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
  }
  function formatQuantity(value, maximumFractionDigits = 2) {
    return Number(value || 0).toLocaleString("cs-CZ", { maximumFractionDigits });
  }
  function parseQuantity(value, fallback = 0) {
    const parsed = Number(String(value != null ? value : "").replace(",", "."));
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
  }
  function getStoragePosition(product) {
    var _a2;
    const match = String((product == null ? void 0 : product.note) || "").match(/\[olvend_storage_position:([^\]]+)\]/);
    return ((_a2 = match == null ? void 0 : match[1]) == null ? void 0 : _a2.trim()) || "";
  }
  function getProductKind(product) {
    if ((product == null ? void 0 : product.product_category) && product.product_category !== "beverage_ready") return product.product_category;
    const match = String((product == null ? void 0 : product.note) || "").match(/\[olvend_product_kind:([a-z_]+)\]/);
    return (match == null ? void 0 : match[1]) || (product == null ? void 0 : product.product_category) || "";
  }
  function getPickingCategory(product) {
    const kind = getProductKind(product);
    if (kind === "water_product") return { key: "waters", label: "Vody", order: 1 };
    if (["snack_ready", "food_ready"].includes(kind)) return { key: "snacks", label: "Cukrovinky", order: 2 };
    return { key: "ingredients", label: "Suroviny", order: 0 };
  }
  function sortPickingItems(items, productsById) {
    return [...items || []].sort((left, right) => {
      const productLeft = productsById.get(String(left.product_id)) || {};
      const productRight = productsById.get(String(right.product_id)) || {};
      const categoryDifference = getPickingCategory(productLeft).order - getPickingCategory(productRight).order;
      if (categoryDifference) return categoryDifference;
      const positionDifference = normalizeText(getStoragePosition(productLeft)).localeCompare(normalizeText(getStoragePosition(productRight)), "cs", { numeric: true });
      if (positionDifference) return positionDifference;
      return normalizeText(left.product_name || productLeft.name).localeCompare(normalizeText(right.product_name || productRight.name), "cs", { numeric: true });
    });
  }
  function getProductPackages(productId, packages) {
    return (packages || []).filter((pack) => String(pack.product_id) === String(productId) && pack.active !== false).sort((left, right) => Number(right.is_default === true) - Number(left.is_default === true) || Number(right.units_per_package || 0) - Number(left.units_per_package || 0));
  }
  function getPickingPackage(item, product, packages) {
    const candidates = getProductPackages(product == null ? void 0 : product.id, packages);
    const itemUnit = normalizeText(item == null ? void 0 : item.unit);
    return candidates.find((pack) => itemUnit && normalizeText(pack.package_name) === itemUnit) || candidates.find((pack) => pack.is_default && Number(pack.units_per_package || 0) > 1) || candidates.find((pack) => Number(pack.units_per_package || 0) > 1) || null;
  }
  function quantityToBase(quantity, unit, product, pack) {
    const amount = Number(quantity || 0);
    if (!pack || normalizeText(unit) === normalizeText((product == null ? void 0 : product.base_unit) || "ks")) return amount;
    if (normalizeText(unit) !== normalizeText(pack.package_name)) return amount;
    return Number((amount * Number(pack.units_per_package || 1)).toFixed(3));
  }
  function quantityFromBase(quantity, mode, product, pack) {
    const amount = Number(quantity || 0);
    if (mode !== "package" || !pack || Number(pack.units_per_package || 0) <= 0) return amount;
    return Number((amount / Number(pack.units_per_package)).toFixed(3));
  }
  function getItemBaseQuantity(item, product, packages, field = "prepared_quantity") {
    var _a2, _b;
    const pack = getPickingPackage(item, product, packages);
    const value = (_b = (_a2 = item == null ? void 0 : item[field]) != null ? _a2 : field === "prepared_quantity" ? item == null ? void 0 : item.requested_quantity : 0) != null ? _b : 0;
    return quantityToBase(value, (item == null ? void 0 : item.unit) || (product == null ? void 0 : product.base_unit) || "ks", product, pack);
  }
  function isSkippedItem(item) {
    return Number((item == null ? void 0 : item.prepared_quantity) || 0) <= 0 && Number((item == null ? void 0 : item.requested_quantity) || 0) > 0 && /\[Nevychystáno:/i.test(String((item == null ? void 0 : item.note) || ""));
  }
  function isHandledItem(item) {
    return Boolean(item == null ? void 0 : item.warehouse_picked_at) || isSkippedItem(item);
  }
  function pluralizeItems(value) {
    const count = Number(value || 0);
    if (count === 1) return "".concat(count, " položka");
    if (count > 1 && count < 5) return "".concat(count, " položky");
    return "".concat(count, " položek");
  }

  // warehouse-picking.js
  var app = document.getElementById("warehousePickingApp");
  var elements = Object.fromEntries([...app.querySelectorAll("[id]")].map((element) => [element.id, element]));
  var views = ["loadingView", "requestsView", "pickingView", "summaryView", "successView", "emptyView", "errorView"];
  var SNAPSHOT_KEY = "olvendWarehousePickingSnapshotV1";
  var QUEUE_KEY = "olvendWarehousePickingQueueV1";
  var SNAPSHOT_FIELDS = ["me", "requests", "items", "products", "packages", "locations", "balances", "employees", "vehicles", "routes"];
  var state = {
    me: null,
    authUserId: null,
    requests: [],
    items: [],
    products: [],
    packages: [],
    locations: [],
    balances: [],
    employees: [],
    vehicles: [],
    routes: [],
    activeRequest: null,
    activeItems: [],
    currentIndex: 0,
    unitMode: "piece",
    quantityPieces: 0,
    deferredInstallPrompt: null,
    busy: false,
    syncing: false
  };
  function readJson(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
    } catch (_) {
      return fallback;
    }
  }
  function readQueue() {
    return readJson(QUEUE_KEY, []);
  }
  function pendingCount() {
    return readQueue().length + getOfflineRequestCount();
  }
  function writeQueue(queue) {
    localStorage.setItem(QUEUE_KEY, JSON.stringify(queue));
    updateConnection();
  }
  function saveSnapshot() {
    const snapshot = Object.fromEntries(SNAPSHOT_FIELDS.map((field) => [field, state[field]]));
    localStorage.setItem(SNAPSHOT_KEY, JSON.stringify(__spreadProps(__spreadValues({}, snapshot), { savedAt: (/* @__PURE__ */ new Date()).toISOString() })));
  }
  function loadSnapshot() {
    const snapshot = readJson(SNAPSHOT_KEY, null);
    if (!(snapshot == null ? void 0 : snapshot.savedAt)) return false;
    SNAPSHOT_FIELDS.forEach((field) => {
      state[field] = snapshot[field] || (field === "me" ? null : []);
    });
    state.activeRequest = null;
    state.activeItems = [];
    return true;
  }
  function updateLocalRow(table, id, payload) {
    var _a2;
    const collection = table === "mobile_stock_requests" ? state.requests : state.items;
    const row = collection.find((candidate) => String(candidate.id) === String(id));
    if (row) Object.assign(row, payload);
    const activeItem = table === "mobile_stock_request_items" ? state.activeItems.find((candidate) => String(candidate.id) === String(id)) : null;
    if (activeItem) Object.assign(activeItem, payload);
    if (table === "mobile_stock_requests" && String((_a2 = state.activeRequest) == null ? void 0 : _a2.id) === String(id)) Object.assign(state.activeRequest, payload);
    saveSnapshot();
  }
  function queueUpdate(table, id, payload) {
    const queue = readQueue();
    queue.push({ id: crypto.randomUUID(), table, rowId: id, payload, queuedAt: (/* @__PURE__ */ new Date()).toISOString() });
    writeQueue(queue);
    updateLocalRow(table, id, payload);
  }
  function applyQueuedUpdates() {
    for (const action of readQueue()) updateLocalRow(action.table, action.rowId, action.payload);
  }
  function isNetworkError(error) {
    const text = String((error == null ? void 0 : error.message) || error || "").toLowerCase();
    return !navigator.onLine || (error == null ? void 0 : error.name) === "AbortError" || /fetch|network|offline|abort|failed to send/.test(text);
  }
  async function updateOrQueue(table, id, payload) {
    if (!navigator.onLine) {
      queueUpdate(table, id, payload);
      return __spreadProps(__spreadValues({}, payload), { __queued: true });
    }
    try {
      const sharedPendingBefore = getOfflineRequestCount();
      const { error } = await supabase.from(table).update(payload).eq("id", id);
      if (error) throw error;
      updateLocalRow(table, id, payload);
      updateConnection();
      return getOfflineRequestCount() > sharedPendingBefore ? __spreadProps(__spreadValues({}, payload), { __queued: true }) : payload;
    } catch (error) {
      if (!isNetworkError(error)) throw error;
      queueUpdate(table, id, payload);
      return __spreadProps(__spreadValues({}, payload), { __queued: true });
    }
  }
  async function syncQueue() {
    if (!navigator.onLine || state.syncing) return { synced: 0, pending: pendingCount() };
    state.syncing = true;
    updateConnection();
    try {
      const queue = readQueue();
      const sharedResult = await syncOfflineRequests();
      if (sharedResult.pending) return { synced: sharedResult.synced, pending: pendingCount() };
      if (!queue.length) return { synced: sharedResult.synced, pending: 0 };
      let synced = 0;
      const remaining = [];
      for (let index = 0; index < queue.length; index += 1) {
        const action = queue[index];
        try {
          const { error } = await supabase.from(action.table).update(action.payload).eq("id", action.rowId);
          if (error) throw error;
          updateLocalRow(action.table, action.rowId, action.payload);
          synced += 1;
        } catch (error) {
          remaining.push(...queue.slice(index));
          if (!isNetworkError(error)) console.error("Offline frontu se nepodařilo synchronizovat:", error);
          break;
        }
      }
      writeQueue(remaining);
      return { synced: synced + sharedResult.synced, pending: remaining.length };
    } finally {
      state.syncing = false;
      updateConnection();
    }
  }
  function showView(id) {
    if (id !== "loadingView") window.__warehousePickingReady = true;
    views.forEach((viewId) => {
      elements[viewId].hidden = viewId !== id;
    });
    window.scrollTo({ top: 0, behavior: "instant" });
  }
  function setBootStage(message) {
    if (typeof window.__warehouseSetBootStage === "function") window.__warehouseSetBootStage(message);
  }
  function showToast(message, type = "") {
    elements.toast.textContent = message;
    elements.toast.className = "toast".concat(type ? " ".concat(type) : "");
    elements.toast.hidden = false;
    window.clearTimeout(showToast.timer);
    showToast.timer = window.setTimeout(() => {
      elements.toast.hidden = true;
    }, 3200);
  }
  function setBusy(busy) {
    state.busy = busy;
    [elements.readyItemBtn, elements.finishRequestBtn, elements.skipItemBtn].forEach((button) => {
      if (button) button.disabled = busy;
    });
  }
  function updateConnection() {
    const online = navigator.onLine;
    const pending = pendingCount();
    elements.connectionState.textContent = state.syncing ? "Synchronizuji · ".concat(pending) : online ? pending ? "Online · čeká ".concat(pending) : "Online" : pending ? "Offline · čeká ".concat(pending) : "Offline";
    elements.connectionState.classList.toggle("offline", !online);
  }
  function employeeName(id) {
    const employee = state.employees.find((row) => String(row.id) === String(id));
    return employee ? [employee.name, employee.surname].filter(Boolean).join(" ") || employee.email || "Operátor" : "Bez operátora";
  }
  function vehicleName(id) {
    const vehicle = state.vehicles.find((row) => String(row.id) === String(id));
    if (!vehicle) return "Bez vozidla";
    return [vehicle.name || [vehicle.brand, vehicle.model].filter(Boolean).join(" "), vehicle.plate].filter(Boolean).join(" · ");
  }
  function routeName(request) {
    const route = state.routes.find((row) => String(row.id) === String(request == null ? void 0 : request.route_plan_id));
    const title = (route == null ? void 0 : route.title) || (route == null ? void 0 : route.name) || "Trasa";
    return (request == null ? void 0 : request.route_plan_id) ? "".concat(title, " · #").concat(request.route_plan_id) : title;
  }
  function requestItems(requestId) {
    return state.items.filter((item) => String(item.request_id) === String(requestId));
  }
  function productById(productId) {
    return state.products.find((product) => String(product.id) === String(productId)) || null;
  }
  function locationForRequest(request, type) {
    const explicitId = type === "warehouse" ? request.source_stock_location_id : request.target_stock_location_id;
    if (explicitId) return state.locations.find((location2) => String(location2.id) === String(explicitId)) || null;
    if (type === "warehouse") {
      return state.locations.find((location2) => location2.location_type === "warehouse" && String(location2.warehouse_id) === String(request.warehouse_id)) || null;
    }
    return state.locations.find((location2) => location2.location_type === "vehicle" && String(location2.vehicle_id) === String(request.vehicle_id)) || null;
  }
  function stockAt(location2, productId) {
    if (!location2) return 0;
    return state.balances.filter((balance) => String(balance.stock_location_id) === String(location2.id) && String(balance.product_id) === String(productId)).reduce((total, balance) => total + Number(balance.quantity_on_hand || 0), 0);
  }
  function itemBaseQuantity(item, field = "prepared_quantity") {
    return getItemBaseQuantity(item, productById(item.product_id), state.packages, field);
  }
  function otherReservations(request, item) {
    return state.requests.filter((candidate) => String(candidate.id) !== String(request.id) && ["requested", "picking", "ready"].includes(candidate.status) && String(candidate.warehouse_id || "") === String(request.warehouse_id || "")).flatMap((candidate) => requestItems(candidate.id)).filter((candidateItem) => String(candidateItem.product_id) === String(item.product_id) && !isSkippedItem(candidateItem)).reduce((total, candidateItem) => total + itemBaseQuantity(candidateItem), 0);
  }
  function formatInMode(baseQuantity, item, product, pack) {
    if (state.unitMode === "package" && pack) {
      return "".concat(formatQuantity(quantityFromBase(baseQuantity, "package", product, pack)), " ").concat(pack.package_name || "bal.");
    }
    return "".concat(formatQuantity(baseQuantity), " ").concat((product == null ? void 0 : product.base_unit) || (item == null ? void 0 : item.unit) || "ks");
  }
  function productFallback(product, item) {
    const source = String((product == null ? void 0 : product.name) || (item == null ? void 0 : item.product_name) || (item == null ? void 0 : item.sku) || "?").trim();
    const words = source.split(/\s+/).filter(Boolean);
    return words.slice(0, 2).map((word) => word[0]).join("").toUpperCase() || "?";
  }
  function renderRequests() {
    const rows = [...state.requests].sort((left, right) => {
      const readyDifference = Number(left.status === "ready") - Number(right.status === "ready");
      if (readyDifference) return readyDifference;
      return String(right.created_at || "").localeCompare(String(left.created_at || ""));
    });
    if (!rows.length) {
      showView("emptyView");
      return;
    }
    elements.requestList.innerHTML = rows.map((request) => {
      const items = requestItems(request.id);
      const handled = items.filter(isHandledItem).length;
      const ready = request.status === "ready";
      const status = ready ? "Čeká na převzetí" : request.status === "picking" ? "Vychystává se" : "Čeká na sklad";
      return '<button class="request-card'.concat(ready ? " ready" : "", '" type="button" data-request-id="').concat(escapeHtml(request.id), '">\n      <span class="request-head"><strong>').concat(escapeHtml(vehicleName(request.vehicle_id)), '</strong><span class="status-pill">').concat(escapeHtml(status), "</span></span>\n      <p>").concat(escapeHtml(routeName(request)), " · ").concat(escapeHtml(employeeName(request.employee_id)), '</p>\n      <span class="request-foot"><span>Požadavek #').concat(escapeHtml(request.id), "</span><b>").concat(escapeHtml("".concat(handled, "/").concat(items.length)), "</b></span>\n    </button>");
    }).join("");
    showView("requestsView");
  }
  function renderRouteHeader() {
    const request = state.activeRequest;
    elements.vehicleLabel.textContent = vehicleName(request.vehicle_id);
    elements.routeLabel.textContent = routeName(request);
    elements.employeeLabel.textContent = employeeName(request.employee_id);
    elements.requestLabel.textContent = "#".concat(request.id);
  }
  function renderProgress() {
    const handled = state.activeItems.filter(isHandledItem).length;
    const total = state.activeItems.length;
    const percent = total ? Math.round(handled / total * 100) : 0;
    elements.progressBar.style.width = "".concat(percent, "%");
    elements.progressLabel.textContent = "".concat(handled, "/").concat(total);
    const progress = elements.progressBar.parentElement;
    progress.setAttribute("aria-valuemax", String(total));
    progress.setAttribute("aria-valuenow", String(handled));
  }
  function renderCategories(activeCategory) {
    const order = ["ingredients", "waters", "snacks"];
    const activeIndex = order.indexOf(activeCategory);
    app.querySelectorAll("[data-category-step]").forEach((step) => {
      const index = order.indexOf(step.dataset.categoryStep);
      step.classList.toggle("active", index === activeIndex);
      step.classList.toggle("done", index < activeIndex);
    });
  }
  function setQuantityFromInput() {
    const item = state.activeItems[state.currentIndex];
    const product = productById(item == null ? void 0 : item.product_id);
    const pack = getPickingPackage(item, product, state.packages);
    const raw = parseQuantity(elements.quantityInput.value, 0);
    state.quantityPieces = state.unitMode === "package" && pack ? Number((raw * Number(pack.units_per_package || 1)).toFixed(3)) : raw;
  }
  function renderQuantityAndStock() {
    const request = state.activeRequest;
    const item = state.activeItems[state.currentIndex];
    const product = productById(item.product_id);
    const pack = getPickingPackage(item, product, state.packages);
    const hasPack = Boolean(pack && Number(pack.units_per_package || 0) > 1);
    if (!hasPack && state.unitMode === "package") state.unitMode = "piece";
    elements.packageModeBtn.disabled = !hasPack;
    elements.packageModeBtn.classList.toggle("active", state.unitMode === "package");
    elements.pieceModeBtn.classList.toggle("active", state.unitMode === "piece");
    const inputValue = state.unitMode === "package" && pack ? quantityFromBase(state.quantityPieces, "package", product, pack) : state.quantityPieces;
    elements.quantityInput.value = String(Number(inputValue.toFixed(3)));
    elements.quantityInput.step = state.unitMode === "package" ? "0.001" : "1";
    elements.quantityUnit.textContent = state.unitMode === "package" ? (pack == null ? void 0 : pack.package_name) || "bal." : (product == null ? void 0 : product.base_unit) || "ks";
    elements.quantitySecondary.textContent = state.unitMode === "package" ? "".concat(formatQuantity(state.quantityPieces), " ").concat((product == null ? void 0 : product.base_unit) || "ks") : hasPack ? "".concat(formatQuantity(quantityFromBase(state.quantityPieces, "package", product, pack)), " ").concat(pack.package_name) : "".concat(formatQuantity(state.quantityPieces), " ").concat((product == null ? void 0 : product.base_unit) || "ks");
    elements.packageNote.textContent = hasPack ? "1 ".concat(pack.package_name, " = ").concat(formatQuantity(pack.units_per_package), " ").concat((product == null ? void 0 : product.base_unit) || "ks") : "Základní jednotka položky";
    const warehouseLocation = locationForRequest(request, "warehouse");
    const vehicleLocation = locationForRequest(request, "vehicle");
    const warehouse = stockAt(warehouseLocation, item.product_id);
    const vehicle = stockAt(vehicleLocation, item.product_id);
    const reserved = otherReservations(request, item);
    const free = warehouse - reserved - state.quantityPieces;
    elements.warehouseStock.textContent = formatInMode(warehouse, item, product, pack);
    elements.vehicleStock.textContent = formatInMode(vehicle, item, product, pack);
    elements.otherReserved.textContent = formatInMode(reserved, item, product, pack);
    elements.freeAfterRequests.textContent = formatInMode(free, item, product, pack);
    elements.freeAfterRequests.parentElement.style.background = free < 0 ? "var(--danger-soft)" : "var(--green-soft)";
    elements.freeAfterRequests.style.color = free < 0 ? "var(--danger)" : "var(--green)";
  }
  function renderCurrentItem() {
    if (!state.activeItems.length) {
      renderSummary();
      return;
    }
    const item = state.activeItems[state.currentIndex];
    const product = productById(item.product_id) || {};
    const category = getPickingCategory(product);
    renderRouteHeader();
    renderProgress();
    renderCategories(category.key);
    elements.itemCounter.textContent = "Položka ".concat(state.currentIndex + 1, " z ").concat(state.activeItems.length);
    elements.itemCategory.textContent = category.label;
    elements.productName.textContent = item.product_name || product.name || "Produkt";
    elements.productSku.textContent = [item.sku || product.sku ? "SKU ".concat(item.sku || product.sku) : "", product.base_unit ? "základ ".concat(product.base_unit) : ""].filter(Boolean).join(" · ") || "Bez kódu";
    elements.productPosition.textContent = getStoragePosition(product) || "Pozice ve skladu není uvedena";
    elements.productFallback.textContent = productFallback(product, item);
    elements.productFallback.hidden = false;
    elements.productPhoto.hidden = true;
    elements.productPhoto.alt = "Fotografie ".concat(item.product_name || product.name || "produktu");
    elements.productPhoto.src = "assets/product-images/".concat(encodeURIComponent(item.product_id), ".webp");
    elements.skipPanel.hidden = true;
    renderQuantityAndStock();
    showView("pickingView");
  }
  function pickNextUnhandled(startAt = 0) {
    const nextIndex = state.activeItems.findIndex((item, index) => index >= startAt && !isHandledItem(item));
    if (nextIndex >= 0) return nextIndex;
    return state.activeItems.findIndex((item) => !isHandledItem(item));
  }
  function resetCurrentQuantity() {
    const item = state.activeItems[state.currentIndex];
    const product = productById(item == null ? void 0 : item.product_id);
    const pack = getPickingPackage(item, product, state.packages);
    state.quantityPieces = item ? itemBaseQuantity(item) : 0;
    state.unitMode = pack && Number(pack.units_per_package || 0) > 1 ? "package" : "piece";
  }
  function advanceAfterItem() {
    const next = pickNextUnhandled(state.currentIndex + 1);
    if (next < 0) {
      renderSummary();
      return;
    }
    state.currentIndex = next;
    resetCurrentQuantity();
    renderCurrentItem();
  }
  function renderSummary() {
    const picked = state.activeItems.filter((item) => Boolean(item.warehouse_picked_at)).length;
    const skipped = state.activeItems.filter(isSkippedItem).length;
    elements.summaryRoute.textContent = "".concat(vehicleName(state.activeRequest.vehicle_id), " · ").concat(employeeName(state.activeRequest.employee_id));
    elements.summaryTotal.textContent = pluralizeItems(state.activeItems.length);
    elements.summaryPicked.textContent = pluralizeItems(picked);
    elements.summarySkipped.textContent = pluralizeItems(skipped);
    showView("summaryView");
  }
  function renderSuccess(request = state.activeRequest) {
    var _a2;
    elements.successRoute.textContent = "".concat(vehicleName(request.vehicle_id), " · ").concat(employeeName(request.employee_id));
    elements.successPreparer.textContent = employeeName(request.prepared_by || ((_a2 = state.me) == null ? void 0 : _a2.id));
    elements.successTime.textContent = request.prepared_at ? new Date(request.prepared_at).toLocaleTimeString("cs-CZ", { hour: "2-digit", minute: "2-digit" }) : (/* @__PURE__ */ new Date()).toLocaleTimeString("cs-CZ", { hour: "2-digit", minute: "2-digit" });
    showView("successView");
  }
  async function openRequest(requestId) {
    const request = state.requests.find((row) => String(row.id) === String(requestId));
    if (!request) throw new Error("Požadavek už není v načteném seznamu.");
    state.activeRequest = request;
    state.activeItems = sortPickingItems(requestItems(request.id), new Map(state.products.map((product) => [String(product.id), product])));
    if (request.status === "ready") {
      renderSuccess(request);
      return;
    }
    if (!state.activeItems.length) throw new Error("Požadavek nemá žádné položky.");
    if (request.status === "requested") {
      await updateOrQueue("mobile_stock_requests", request.id, { status: "picking", prepared_at: null });
    }
    const next = pickNextUnhandled(0);
    if (next < 0) {
      renderSummary();
      return;
    }
    state.currentIndex = next;
    resetCurrentQuantity();
    renderCurrentItem();
  }
  async function saveCurrentItem() {
    var _a2;
    setQuantityFromInput();
    if (state.quantityPieces <= 0) throw new Error("Pro nulové množství použij tlačítko Nevychystat.");
    const item = state.activeItems[state.currentIndex];
    const product = productById(item.product_id) || {};
    const pack = getPickingPackage(item, product, state.packages);
    const requestedBase = itemBaseQuantity(item, "requested_quantity");
    const usePackage = state.unitMode === "package" && pack;
    const unit = usePackage ? pack.package_name : product.base_unit || "ks";
    const factor = usePackage ? Number(pack.units_per_package || 1) : 1;
    const now = (/* @__PURE__ */ new Date()).toISOString();
    const cleanNote = String(item.note || "").replace(/\s*\[Nevychystáno:[^\]]+\]/gi, "").trim() || null;
    const payload = {
      unit,
      requested_quantity: Number((requestedBase / factor).toFixed(3)),
      prepared_quantity: Number((state.quantityPieces / factor).toFixed(3)),
      note: cleanNote,
      warehouse_picked_at: now,
      warehouse_picked_by: ((_a2 = state.me) == null ? void 0 : _a2.id) || null
    };
    const data = await updateOrQueue("mobile_stock_request_items", item.id, payload);
    showToast("".concat(item.product_name || product.name, ": připraveno").concat(data.__queued ? " offline" : "", "."));
    advanceAfterItem();
  }
  async function skipCurrentItem(reason) {
    const item = state.activeItems[state.currentIndex];
    const cleanNote = String(item.note || "").replace(/\s*\[Nevychystáno:[^\]]+\]/gi, "").trim();
    const payload = {
      prepared_quantity: 0,
      note: [cleanNote, "[Nevychystáno: ".concat(reason, "]")].filter(Boolean).join(" "),
      warehouse_picked_at: null,
      warehouse_picked_by: null
    };
    const data = await updateOrQueue("mobile_stock_request_items", item.id, payload);
    showToast("".concat(item.product_name || "Položka", ": nevychystáno · ").concat(reason).concat(data.__queued ? " · uloženo offline" : ""));
    advanceAfterItem();
  }
  async function finishRequest() {
    var _a2;
    let checkedItems = state.activeItems;
    if (navigator.onLine && !pendingCount()) {
      const { data: freshItems, error: itemsError } = await supabase.from("mobile_stock_request_items").select("*").eq("request_id", state.activeRequest.id).order("id", { ascending: true });
      if (itemsError) throw itemsError;
      checkedItems = freshItems || [];
    }
    const unhandled = checkedItems.filter((item) => !isHandledItem(item));
    if (unhandled.length) throw new Error("Ještě zbývá zkontrolovat ".concat(pluralizeItems(unhandled.length), "."));
    const now = (/* @__PURE__ */ new Date()).toISOString();
    const payload = { status: "ready", prepared_at: now, prepared_by: ((_a2 = state.me) == null ? void 0 : _a2.id) || null };
    await updateOrQueue("mobile_stock_requests", state.activeRequest.id, payload);
    renderSuccess(state.activeRequest);
  }
  async function getCurrentEmployee() {
    if (!navigator.onLine) {
      const snapshot = readJson(SNAPSHOT_KEY, null);
      if (snapshot == null ? void 0 : snapshot.me) return snapshot.me;
      throw new Error("Pro první otevření skladu je potřeba internet. Potom bude fungovat i offline.");
    }
    const authUserId = state.authUserId;
    if (!authUserId) throw new Error("Přihlášení vypršelo. Přihlas se znovu do OLVEND.");
    const { data, error } = await supabase.from("employees").select("id, name, surname, email, role").eq("auth_user_id", authUserId).maybeSingle();
    if (error) throw error;
    if (!data) throw new Error("K přihlášení není přiřazený zaměstnanec.");
    return data;
  }
  async function loadData() {
    var _a2, _b;
    showView("loadingView");
    setBootStage("Spouštím skladovou aplikaci…");
    const hardTimeout = window.setTimeout(() => {
      if (elements.loadingView.hidden) return;
      elements.errorMessage.textContent = "Načítání se zastavilo. Zkontroluj připojení a zvol „Přihlásit se znovu“.";
      showView("errorView");
    }, 15e3);
    try {
      if (!navigator.onLine) {
        setBootStage("Načítám poslední uložená data…");
        if (!loadSnapshot()) throw new Error("Offline data zatím nejsou uložená. Připoj Zebru k internetu a otevři sklad znovu.");
        renderRequests();
        return;
      }
      setBootStage("Ověřuji uložené přihlášení…");
      const session = await ensureWarehouseSession();
      state.authUserId = session && session.user && session.user.id;
      setBootStage("Kontroluji neodeslané změny…");
      await syncQueue();
      setBootStage("Načítám pracovníka skladu…");
      state.me = await getCurrentEmployee();
      setBootStage("Načítám požadavky na vychystání…");
      const { data: requests, error: requestsError } = await supabase.from("mobile_stock_requests").select("*").in("request_type", ["vehicle_order", "vehicle_load"]).in("status", ["requested", "picking", "ready"]).order("created_at", { ascending: false }).limit(100);
      if (requestsError) throw requestsError;
      state.requests = requests || [];
      if (!state.requests.length) {
        state.items = [];
        saveSnapshot();
        renderRequests();
        return;
      }
      const requestIds = state.requests.map((request) => request.id);
      const employeeIds = [...new Set(state.requests.flatMap((request) => [request.employee_id, request.prepared_by]).filter(Boolean))];
      const vehicleIds = [...new Set(state.requests.map((request) => request.vehicle_id).filter(Boolean))];
      const routeIds = [...new Set(state.requests.map((request) => request.route_plan_id).filter(Boolean))];
      setBootStage("Načítám položky, vozidla a trasy…");
      const [itemsResult, employeesResult, vehiclesResult, routesResult, locationsResult] = await Promise.all([
        supabase.from("mobile_stock_request_items").select("*").in("request_id", requestIds).order("id", { ascending: true }),
        employeeIds.length ? supabase.from("employee_directory").select("id, name, surname, email").in("id", employeeIds) : Promise.resolve({ data: [], error: null }),
        vehicleIds.length ? supabase.from("vehicles").select("id, name, plate, brand, model, warehouse_id").in("id", vehicleIds) : Promise.resolve({ data: [], error: null }),
        routeIds.length ? supabase.from("route_plans").select("id, title, planning_date").in("id", routeIds) : Promise.resolve({ data: [], error: null }),
        supabase.from("stock_locations").select("id, name, location_type, warehouse_id, vehicle_id, active").eq("active", true)
      ]);
      const firstError = (_a2 = [itemsResult, employeesResult, vehiclesResult, routesResult, locationsResult].find((result) => result.error)) == null ? void 0 : _a2.error;
      if (firstError) throw firstError;
      state.items = itemsResult.data || [];
      state.employees = [...employeesResult.data || []];
      if (!state.employees.some((employee) => String(employee.id) === String(state.me.id))) state.employees.push(state.me);
      state.vehicles = vehiclesResult.data || [];
      state.routes = routesResult.data || [];
      state.locations = locationsResult.data || [];
      const productIds = [...new Set(state.items.map((item) => item.product_id).filter(Boolean))];
      const relevantLocationIds = [...new Set(state.requests.flatMap((request) => {
        var _a3, _b2;
        return [
          request.source_stock_location_id,
          request.target_stock_location_id,
          (_a3 = locationForRequest(request, "warehouse")) == null ? void 0 : _a3.id,
          (_b2 = locationForRequest(request, "vehicle")) == null ? void 0 : _b2.id
        ];
      }).filter(Boolean))];
      setBootStage("Načítám produkty a skladové zásoby…");
      const [productsResult, packagesResult, balancesResult] = await Promise.all([
        productIds.length ? supabase.from("products").select("id, name, sku, product_category, usage_type, base_unit, active, note").in("id", productIds) : Promise.resolve({ data: [], error: null }),
        productIds.length ? supabase.from("product_packages").select("id, product_id, package_name, units_per_package, is_default, active").in("product_id", productIds).eq("active", true) : Promise.resolve({ data: [], error: null }),
        relevantLocationIds.length && productIds.length ? supabase.from("stock_location_balances").select("id, stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity").in("stock_location_id", relevantLocationIds).in("product_id", productIds) : Promise.resolve({ data: [], error: null })
      ]);
      const detailError = (_b = [productsResult, packagesResult, balancesResult].find((result) => result.error)) == null ? void 0 : _b.error;
      if (detailError) throw detailError;
      state.products = productsResult.data || [];
      state.packages = packagesResult.data || [];
      state.balances = balancesResult.data || [];
      state.activeRequest = null;
      state.activeItems = [];
      applyQueuedUpdates();
      saveSnapshot();
      renderRequests();
    } catch (error) {
      console.error(error);
      elements.errorMessage.textContent = (error == null ? void 0 : error.message) || "Zkus stránku obnovit.";
      showView("errorView");
    } finally {
      window.clearTimeout(hardTimeout);
    }
  }
  async function runAction(action) {
    if (state.busy) return;
    setBusy(true);
    try {
      await action();
    } catch (error) {
      console.error(error);
      showToast((error == null ? void 0 : error.message) || "Akci se nepodařilo uložit.", "error");
    } finally {
      setBusy(false);
    }
  }
  elements.requestList.addEventListener("click", (event) => {
    const button = event.target.closest("[data-request-id]");
    if (button) runAction(() => openRequest(button.dataset.requestId));
  });
  elements.refreshBtn.addEventListener("click", loadData);
  elements.emptyRefreshBtn.addEventListener("click", loadData);
  elements.errorRetryBtn.addEventListener("click", loadData);
  elements.backToRequestsBtn.addEventListener("click", renderRequests);
  elements.successBackBtn.addEventListener("click", loadData);
  elements.readyItemBtn.addEventListener("click", () => runAction(saveCurrentItem));
  elements.skipItemBtn.addEventListener("click", () => {
    elements.skipPanel.hidden = !elements.skipPanel.hidden;
  });
  elements.skipPanel.addEventListener("click", (event) => {
    const button = event.target.closest("[data-skip-reason]");
    if (button) runAction(() => skipCurrentItem(button.dataset.skipReason));
  });
  elements.finishRequestBtn.addEventListener("click", () => runAction(finishRequest));
  elements.reviewItemsBtn.addEventListener("click", () => {
    state.currentIndex = Math.max(0, state.activeItems.length - 1);
    resetCurrentQuantity();
    renderCurrentItem();
  });
  elements.minusBtn.addEventListener("click", () => {
    const item = state.activeItems[state.currentIndex];
    const product = productById(item == null ? void 0 : item.product_id);
    const pack = getPickingPackage(item, product, state.packages);
    const step = state.unitMode === "package" && pack ? Number(pack.units_per_package || 1) : 1;
    state.quantityPieces = Math.max(0, Number((state.quantityPieces - step).toFixed(3)));
    renderQuantityAndStock();
  });
  elements.plusBtn.addEventListener("click", () => {
    const item = state.activeItems[state.currentIndex];
    const product = productById(item == null ? void 0 : item.product_id);
    const pack = getPickingPackage(item, product, state.packages);
    const step = state.unitMode === "package" && pack ? Number(pack.units_per_package || 1) : 1;
    state.quantityPieces = Number((state.quantityPieces + step).toFixed(3));
    renderQuantityAndStock();
  });
  elements.packageModeBtn.addEventListener("click", () => {
    state.unitMode = "package";
    renderQuantityAndStock();
  });
  elements.pieceModeBtn.addEventListener("click", () => {
    state.unitMode = "piece";
    renderQuantityAndStock();
  });
  elements.quantityInput.addEventListener("input", () => {
    setQuantityFromInput();
    renderQuantityAndStock();
  });
  elements.productPhoto.addEventListener("load", () => {
    elements.productPhoto.hidden = false;
    elements.productFallback.hidden = true;
  });
  elements.productPhoto.addEventListener("error", () => {
    elements.productPhoto.hidden = true;
    elements.productFallback.hidden = false;
  });
  window.addEventListener("online", async () => {
    updateConnection();
    const result = await syncQueue();
    showToast(result.synced ? "Synchronizováno ".concat(result.synced, " změn.") : "Připojení je znovu dostupné.");
    if (!result.pending) await loadData();
  });
  window.addEventListener("offline", updateConnection);
  window.addEventListener("olvend-offline-queue", updateConnection);
  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    state.deferredInstallPrompt = event;
    elements.installAppBtn.hidden = false;
  });
  elements.installAppBtn.addEventListener("click", async () => {
    if (!state.deferredInstallPrompt) return;
    state.deferredInstallPrompt.prompt();
    await state.deferredInstallPrompt.userChoice;
    state.deferredInstallPrompt = null;
    elements.installAppBtn.hidden = true;
  });
  updateConnection();
  loadData();
})();
