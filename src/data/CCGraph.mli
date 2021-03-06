(*
copyright (c) 2013-2015, simon cruanes
all rights reserved.

redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.  redistributions in binary
form must reproduce the above copyright notice, this list of conditions and the
following disclaimer in the documentation and/or other materials provided with
the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)

(** {1 Simple Graph Interface}

    A collections of algorithms on (mostly read-only) graph structures.
    The user provides her own graph structure as a [('v, 'e) CCGraph.t],
    where ['v] is the type of vertices and ['e] the type of edges
    (for instance, ['e = ('v * 'v)] is perfectly fine in many cases).

    Such a [('v, 'e) CCGraph.t] structure is a record containing
    three functions: two relate edges to their origin and destination,
    and one maps vertices to their outgoing edges.
    This abstract notion of graph makes it possible to run the algorithms
    on any user-specific type that happens to have a graph structure.

    Many graph algorithms here take a sequence of vertices as input.
    If the user only has a single vertex (e.g., for a topological sort
    from a given vertex), she can use [Seq.return x] to build a sequence
    of one element.

    {b status: unstable}

    @since 0.12 *)

type 'a sequence = ('a -> unit) -> unit
(** A sequence of items of type ['a], possibly infinite *)

type 'a sequence_once = 'a sequence
(** Sequence that should be used only once *)

exception Sequence_once
(** Raised when a sequence meant to be used once is used several times *)

module Seq : sig
  type 'a t = 'a sequence
  val return : 'a -> 'a sequence
  val (>>=) : 'a t -> ('a -> 'b t) -> 'b t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val filter_map : ('a -> 'b option) -> 'a t -> 'b t
  val iter : ('a -> unit) -> 'a t -> unit
  val fold: ('b -> 'a -> 'b) -> 'b -> 'a t -> 'b
  val to_list : 'a t -> 'a list
end

(** {2 Interfaces for graphs} *)

(** Directed graph with vertices of type ['v] and edges of type [e'] *)
type ('v, 'e) t = {
  children: 'v -> 'e sequence;
  origin: 'e -> 'v;
  dest: 'e -> 'v;
}

type ('v, 'e) graph = ('v, 'e) t

val make :
  origin:('e -> 'v) ->
  dest:('e -> 'v) ->
  ('v -> 'e sequence) -> ('v, 'e) t
(** Make a graph by providing its fields
    @since 0.16 *)

val make_labelled_tuple :
  ('v -> ('a * 'v) sequence) -> ('v, ('v * 'a * 'v)) t
(** Make a graph with edges being triples [(origin,label,dest)]
    @since 0.16 *)

val make_tuple :
  ('v -> 'v sequence) -> ('v, ('v * 'v)) t
(** Make a graph with edges being pairs [(origin,dest)]
    @since 0.16 *)

(** Mutable tags from values of type ['v] to tags of type [bool] *)
type 'v tag_set = {
  get_tag: 'v -> bool;
  set_tag: 'v -> unit; (** Set tag for the given element *)
}

(** Mutable table with keys ['k] and values ['a] *)
type ('k, 'a) table = {
  mem: 'k -> bool;
  find: 'k -> 'a;  (** @raise Not_found if element not added before *)
  add: 'k -> 'a -> unit; (** Erases previous binding *)
}

(** Mutable set *)
type 'a set = ('a, unit) table

val mk_table: ?eq:('k -> 'k -> bool) -> ?hash:('k -> int) -> int -> ('k, 'a) table
(** Default implementation for {!table}: a {!Hashtbl.t} *)

val mk_map: ?cmp:('k -> 'k -> int) -> unit -> ('k, 'a) table
(** Use a {!Map.S} underneath *)

(** {2 Bags of vertices} *)

(** Bag of elements of type ['a] *)
type 'a bag = {
  push: 'a -> unit;
  is_empty: unit -> bool;
  pop: unit -> 'a;  (** raises some exception is empty *)
}

val mk_queue: unit -> 'a bag
val mk_stack: unit -> 'a bag

val mk_heap: leq:('a -> 'a -> bool) -> 'a bag
(** [mk_heap ~leq] makes a priority queue where [leq x y = true] means that
    [x] is smaller than [y] and should be prioritary *)

(** {2 Traversals} *)

module Traverse : sig
  type 'e path = 'e list

  val generic: ?tbl:'v set ->
                bag:'v bag ->
                graph:('v, 'e) t ->
                'v sequence ->
                'v sequence_once
  (** Traversal of the given graph, starting from a sequence
      of vertices, using the given bag to choose the next vertex to
      explore. Each vertex is visited at most once. *)

  val generic_tag: tags:'v tag_set ->
                   bag:'v bag ->
                   graph:('v, 'e) t ->
                   'v sequence ->
                   'v sequence_once
  (** One-shot traversal of the graph using a tag set and the given bag *)

  val dfs: ?tbl:'v set ->
           graph:('v, 'e) t ->
           'v sequence ->
           'v sequence_once

  val dfs_tag: tags:'v tag_set ->
               graph:('v, 'e) t ->
               'v sequence ->
               'v sequence_once

  val bfs: ?tbl:'v set ->
           graph:('v, 'e) t ->
           'v sequence ->
           'v sequence_once

  val bfs_tag: tags:'v tag_set ->
               graph:('v, 'e) t ->
               'v sequence ->
               'v sequence_once

  val dijkstra : ?tbl:'v set ->
                  ?dist:('e -> int) ->
                  graph:('v, 'e) t ->
                  'v sequence ->
                  ('v * int * 'e path) sequence_once
  (** Dijkstra algorithm, traverses a graph in increasing distance order.
      Yields each vertex paired with its distance to the set of initial vertices
      (the smallest distance needed to reach the node from the initial vertices)
      @param dist distance from origin of the edge to destination,
        must be strictly positive. Default is 1 for every edge *)

  val dijkstra_tag : ?dist:('e -> int) ->
                      tags:'v tag_set ->
                      graph:('v, 'e) t ->
                      'v sequence ->
                      ('v * int * 'e path) sequence_once

  (** {2 More detailed interface} *)
  module Event : sig
    type edge_kind = [`Forward | `Back | `Cross ]

    (** A traversal is a sequence of such events *)
    type ('v,'e) t =
      [ `Enter of 'v * int * 'e path  (* unique index in traversal, path from start *)
      | `Exit of 'v
      | `Edge of 'e * edge_kind
      ]

    val get_vertex : ('v, 'e) t -> ('v * [`Enter | `Exit]) option
    val get_enter : ('v, 'e) t -> 'v option
    val get_exit : ('v, 'e) t -> 'v option
    val get_edge : ('v, 'e) t -> 'e option
    val get_edge_kind : ('v, 'e) t -> ('e * edge_kind) option

    val dfs: ?tbl:'v set ->
             ?eq:('v -> 'v -> bool) ->
             graph:('v, 'e) graph ->
             'v sequence ->
             ('v,'e) t sequence_once
    (** Full version of DFS.
        @param eq equality predicate on vertices *)

    val dfs_tag: ?eq:('v -> 'v -> bool) ->
                 tags:'v tag_set ->
                 graph:('v, 'e) graph ->
                 'v sequence ->
                 ('v,'e) t sequence_once
    (** Full version of DFS using integer tags
        @param eq equality predicate on vertices *)
  end
end

(** {2 Cycles} *)

val is_dag :
  ?tbl:'v set ->
  graph:('v, _) t ->
  'v sequence ->
  bool
(** [is_dag ~graph vs] returns [true] if the subset of [graph] reachable
    from [vs] is acyclic.
    @since 0.18 *)

(** {2 Topological Sort} *)

exception Has_cycle

val topo_sort : ?eq:('v -> 'v -> bool) ->
                ?rev:bool ->
                ?tbl:'v set ->
                graph:('v, 'e) t ->
                'v sequence ->
                'v list
(** [topo_sort ~graph seq] returns a list of vertices [l] where each
    element of [l] is reachable from [seq].
    The list is sorted in a way such that if [v -> v'] in the graph, then
    [v] comes before [v'] in the list (i.e. has a smaller index).
    Basically [v -> v'] means that [v] is smaller than [v']
    see {{: https://en.wikipedia.org/wiki/Topological_sorting} wikipedia}
    @param eq equality predicate on vertices (default [(=)])
    @param rev if true, the dependency relation is inverted ([v -> v'] means
      [v'] occurs before [v])
    @raise Has_cycle if the graph is not a DAG *)

val topo_sort_tag : ?eq:('v -> 'v -> bool) ->
                    ?rev:bool ->
                    tags:'v tag_set ->
                    graph:('v, 'e) t ->
                    'v sequence ->
                    'v list
(** Same as {!topo_sort} but uses an explicit tag set *)

(** {2 Lazy Spanning Tree} *)

module LazyTree : sig
  type ('v, 'e) t =
    | Vertex of 'v * ('e * ('v, 'e) t) list Lazy.t

  val map_v : ('a -> 'b) -> ('a, 'e) t -> ('b, 'e) t

  val fold_v : ('acc -> 'v -> 'acc) -> 'acc -> ('v, _) t -> 'acc
end

val spanning_tree : ?tbl:'v set ->
                    graph:('v, 'e) t ->
                    'v ->
                    ('v, 'e) LazyTree.t
(** [spanning_tree ~graph v] computes a lazy spanning tree that has [v]
    as a root. The table [tbl] is used for the memoization part *)

val spanning_tree_tag : tags:'v tag_set ->
                        graph:('v, 'e) t ->
                        'v ->
                        ('v, 'e) LazyTree.t

(** {2 Strongly Connected Components} *)

type 'v scc_state
(** Hidden state for {!scc} *)

val scc : ?tbl:('v, 'v scc_state) table ->
          graph:('v, 'e) t ->
          'v sequence ->
          'v list sequence_once
(** Strongly connected components reachable from the given vertices.
    Each component is a list of vertices that are all mutually reachable
    in the graph.
    The components are explored in a topological order (if C1 and C2 are
    components, and C1 points to C2, then C2 will be yielded before C1).
    Uses {{: https://en.wikipedia.org/wiki/Tarjan's_strongly_connected_components_algorithm} Tarjan's algorithm}
    @param tbl table used to map nodes to some hidden state
    @raise Sequence_once if the result is iterated on more than once.
    *)

(** {2 Pretty printing in the DOT (graphviz) format}

    Example (print divisors from [42]):

    {[
      let open CCGraph in
      let open Dot in
      with_out "/tmp/truc.dot"
        (fun out ->
           pp ~attrs_v:(fun i -> [`Label (string_of_int i)]) ~graph:divisors_graph out 42
        )
    ]}

*)

module Dot : sig
  type attribute = [
  | `Color of string
  | `Shape of string
  | `Weight of int
  | `Style of string
  | `Label of string
  | `Other of string * string
  ] (** Dot attribute *)

  type vertex_state
  (** Hidden state associated to a vertex *)

  val pp : ?tbl:('v,vertex_state) table ->
           ?eq:('v -> 'v -> bool) ->
           ?attrs_v:('v -> attribute list) ->
           ?attrs_e:('e -> attribute list) ->
           ?name:string ->
           graph:('v,'e) t ->
           Format.formatter ->
           'v ->
           unit
  (** Print the graph, starting from given vertex, on the formatter
      @param attrs_v attributes for vertices
      @param attrs_e attributes for edges
      @param name name of the graph *)

  val pp_seq : ?tbl:('v,vertex_state) table ->
               ?eq:('v -> 'v -> bool) ->
               ?attrs_v:('v -> attribute list) ->
               ?attrs_e:('e -> attribute list) ->
               ?name:string ->
               graph:('v,'e) t ->
               Format.formatter ->
               'v sequence ->
               unit

  val with_out : string -> (Format.formatter -> 'a) -> 'a
  (** Shortcut to open a file and write to it *)
end

(** {2 Mutable Graph} *)

type ('v, 'e) mut_graph = <
  graph: ('v, 'e) t;
  add_edge: 'e -> unit;
  remove : 'v -> unit;
>

val mk_mut_tbl : ?eq:('v -> 'v -> bool) ->
                 ?hash:('v -> int) ->
                int ->
                ('v, ('v * 'a * 'v)) mut_graph
(** Make a new mutable graph from a Hashtbl. Edges are labelled with type ['a] *)

(** {2 Immutable Graph}

    A classic implementation of a graph structure on totally ordered vertices,
    with unlabelled edges. The graph allows to add and remove edges and vertices,
    and to iterate on edges and vertices.
*)

module type MAP = sig
  type vertex
  type t

  val as_graph : t -> (vertex, (vertex * vertex)) graph
  (** Graph view of the map *)

  val empty : t

  val add_edge : vertex -> vertex -> t -> t

  val remove_edge : vertex -> vertex -> t -> t

  val add : vertex -> t -> t
  (** Add a vertex, possibly with no outgoing edge *)

  val remove : vertex -> t -> t
  (** Remove the vertex and all its outgoing edges.
      Edges that point to the vertex are {b NOT} removed, they must be
      manually removed with {!remove_edge} *)

  val union : t -> t -> t

  val vertices : t -> vertex sequence

  val vertices_l : t -> vertex list

  val of_list : (vertex * vertex) list -> t

  val add_list : (vertex * vertex) list -> t -> t

  val to_list : t -> (vertex * vertex) list

  val of_seq : (vertex * vertex) sequence -> t

  val add_seq : (vertex * vertex) sequence -> t -> t

  val to_seq : t -> (vertex * vertex) sequence
end

module Map(O : Map.OrderedType) : MAP with type vertex = O.t

(** {2 Misc} *)

val of_list : ?eq:('v -> 'v -> bool) -> ('v * 'v) list -> ('v, ('v * 'v)) t
(** [of_list l] makes a graph from a list of pairs of vertices.
    Each pair [(a,b)] is an edge from [a] to [b].
    @param eq equality used to compare vertices *)

val of_hashtbl : ('v, 'v list) Hashtbl.t -> ('v, ('v * 'v)) t
(** [of_hashtbl tbl] makes a graph from a hashtable that maps vertices
    to lists of children *)

val of_fun : ('v -> 'v list) -> ('v, ('v * 'v)) t
(** [of_fun f] makes a graph out of a function that maps a vertex to
    the list of its children. The function is assumed to be deterministic. *)

val divisors_graph : (int, (int * int)) t
(** [n] points to all its strict divisors *)
