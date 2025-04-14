/*******************************************************************************

    TIDI

*******************************************************************************/

module configy.backend.json;

import configy.backend.node;

import std.algorithm;
import std.exception;
static import std.file;
import std.format;
import std.json;

/**
 * Parses a file at `path` and return a node suitable for `parseConfig`
 *
 * Parses a file located at `path`, expected to contain YAML (or JSON),
 * and return a node that can be passed to `configy.read : parseConfig`.
 *
 * Params:
 *   path = Path to the file to load.
 *
 * Returns:
 *   A mapping representing the document.
 *
 * Throws:
 *   If the file cannot be loaded or the root of the document is not a mapping.
 */
public JSONNode parseFile (string path) {
    return new JSONNode(parseJSON(std.file.readText(path)), Location(path));
}

/**
 * Parses YAML `content` and return a node suitable for `parseConfig`
 *
 * Parses a string expecting to contain properly formatted YAML / JSON,
 * with an optional associated path (or symbolic name) and returns a node
 * that can then be passed to `configy.read : parseConfig`.
 *
 * Params:
 *   content = Content of the YAML / JSON document to read.
 *   path = Path to associate to the content. It may be `null`.
 *
 * Returns:
 *   A mapping representing the document.
 *
 * Throws:
 *   If loading the content failed.
 */
public JSONNode parseString (string content, string path) {
    return new JSONNode(parseJSON(content), Location(path));
}

/// The base class for all YAML nodes
public class JSONNode : Node, Mapping, Sequence, Scalar {
    /// The underlying data
    protected JSONValue n;
    /// The location of this node
    protected Location l;

    ///
    public this (JSONValue node, Location loc) @safe pure {
        this.n = node;
        this.l = loc;
    }

    ///
    public override Location location () const scope @safe nothrow {
        return this.l;
    }

    public override inout(Mapping)  asMapping () inout scope @safe {
        return this.n.type.among(JSONType.object, JSONType.null_) ? this : null;
    }
    public override inout(Sequence) asSequence () inout scope @safe {
        return this.n.type.among(JSONType.object, JSONType.null_) ? this : null;
    }
    public override inout(Scalar)   asScalar () inout scope @safe {
        return !this.n.type.among(JSONType.object, JSONType.array) ? this : null;
    }

    /// Returns a string representation of this Scalar
    public override Type type () const scope @safe nothrow {
        switch (this.n.type) {
            case JSONType.array:
                return Type.Sequence;
            case JSONType.object:
            case JSONType.null_:
                return Type.Mapping;
            default:
                return Type.Scalar;
        }
    }

    /// Returns: The length of this object (the number of entries in it)
    public override size_t length () const scope @safe {
        switch (this.n.type) {
            case JSONType.array:
                return this.n.arrayNoRef.length;
            case JSONType.object:
                return this.n.objectNoRef.length;
            default:
                throw new Exception("Object is not a mapping or a sequence");
        }
    }

    /// Iterates over this object, passing each entry to the `dg`
    public override int opApply (scope MapIterator dg) scope {
        foreach (scope pair; this.n.objectNoRef().byKeyValue()) {
            scope kn = new JSONNode(JSONValue(pair.key), this.l);
            scope kv = new JSONNode(pair.value, this.l);
            if (auto res = dg(kn, kv))
                return res;
        }
        return 0;
    }

    /// Iterates over this sequence, passing each entry to the `dg`
    public override int opApply (scope SeqIterator dg) scope {
        foreach (size_t idx, scope value; this.n.arrayNoRef()) {
            scope val = new JSONNode(value, this.l);
            if (auto res = dg(idx, val))
                return res;
        }
        return 0;
    }

    /// Returns a string representation of this Scalar
    public override string str () const scope return @safe {
        import std.conv;

        final switch (this.n.type) {
            case JSONType.array:
            case JSONType.object:
                throw new Exception("Object is not a scalar");
            case JSONType.null_:
                return null;
            case JSONType.true_:
                return "true";
            case JSONType.false_:
                return "false";
            case JSONType.string:
                return this.n.str;
            case JSONType.integer:
                return this.n.integer().to!string;
            case JSONType.uinteger:
                return this.n.uinteger().to!string;
            case JSONType.float_:
                return this.n.floating().to!string;
        }
    }
}
