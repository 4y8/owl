(*
 * OWL - an OCaml numerical library for scientific computing
 * Copyright (c) 2016-2017 Liang Wang <liang.wang@cl.cam.ac.uk>
 *)

open Owl_nlp_utils

type tf_typ =
  | Binary
  | Count
  | Frequency
  | Log_norm

type df_typ =
  | Unary
  | Idf
  | Idf_Smooth

type t = {
  mutable uri       : string;           (* file path of the model *)
  mutable tf_typ    : tf_typ;           (* function to calculate term freq *)
  mutable df_typ    : df_typ;           (* function to calculate doc freq *)
  mutable offset    : int array;        (* record the offest each document *)
  mutable doc_freq  : float array;      (* document frequency *)
  mutable corpus    : Owl_nlp_corpus.t  (* corpus type *)
}

(* variouis types of TF and IDF fucntions *)

let term_freq = function
  | Binary    -> fun tc tn -> 1.
  | Count     -> fun tc tn -> tc
  | Frequency -> fun tc tn -> tc /. tn
  | Log_norm  -> fun tc tn -> 1. +. log tc

let doc_freq = function
  | Unary      -> fun dc nd -> 1.
  | Idf        -> fun dc nd -> log (nd /. dc)
  | Idf_Smooth -> fun dc nd -> log (nd /. (1. +. dc))


let create tf_typ df_typ corpus =
  let base_uri = Owl_nlp_corpus.get_uri corpus in
  {
    uri      = base_uri ^ ".tfidf";
    tf_typ;
    df_typ;
    offset   = [||];
    doc_freq = [||];
    corpus;
  }


(* calculate document frequency for a given word *)
let doc_count_of m w =
  let v = Owl_nlp_corpus.get_vocab m.corpus in
  let i = Owl_nlp_vocabulary.word2index v w in
  m.doc_freq.(i)


(* count occurrency in all documents, for all words *)
let doc_count vocab fname =
  let n_w = Owl_nlp_vocabulary.length vocab in
  let d_f = Array.make n_w 0. in
  let _h = Hashtbl.create 1024 in
  let n_d = ref 0 in
  Owl_nlp_utils.iteri_lines_of_marshal (fun i doc ->
    Hashtbl.clear _h;
    Array.iter (fun w ->
      match Hashtbl.mem _h w with
      | true  -> ()
      | false -> Hashtbl.add _h w 0
    ) doc;
    Hashtbl.iter (fun w _ ->
      d_f.(w) <- d_f.(w) +. 1.
    ) _h;
    n_d := i;
  ) fname;
  d_f, !n_d


(* count the term occurrency in a document *)
let term_count _h doc =
  Array.iter (fun w ->
    match Hashtbl.mem _h w with
    | true  -> (
        let a = Hashtbl.find _h w in
        Hashtbl.replace _h w (a +. 1.)
      )
    | false -> Hashtbl.add _h w 1.
  ) doc


(* build TF-IDF model from an empty model, m: empty tf-idf model *)
let _build_with tf_fun df_fun m =
  let vocab = Owl_nlp_corpus.get_vocab m.corpus in
  let tfile = Owl_nlp_corpus.get_tok_uri m.corpus in
  let fname = m.uri in

  Log.info "calculate document frequency ...";
  let d_f, n_d = doc_count vocab tfile in
  let n_d = Owl_nlp_corpus.length m.corpus |> float_of_int in
  m.doc_freq <- d_f;

  Log.info "calculate tf-idf ...";
  (* buffer for calculate term frequency *)
  let _h = Hashtbl.create 1024 in
  (* variable for tracking the offest in output model *)
  let offset = Owl_utils.Stack.make () in
  let fo = open_out fname in

  Owl_nlp_utils.iteri_lines_of_marshal (fun i doc ->
    (* first count terms in one doc *)
    term_count _h doc;

    (* prepare temporary variables *)
    let tfs = Array.make (Hashtbl.length _h) (0, 0.) in
    let tn = Array.length doc |> float_of_int in
    let j = ref 0 in

    (* calculate tf-idf values *)
    Hashtbl.iter (fun w tc ->
      let tf_df = (tf_fun tc tn) *. (df_fun d_f.(w) n_d) in
      tfs.(!j) <- w, tf_df;
      j := !j + 1;
    ) _h;
    Marshal.to_channel fo tfs [];
    Owl_utils.Stack.push offset (LargeFile.pos_out fo |> Int64.to_int);

    (* remember to clear the buffer *)
    Hashtbl.clear _h;
  ) tfile;

  (* finished, clean up *)
  m.offset <- offset |> Owl_utils.Stack.to_array;
  close_out fo


let build ?(tf=Count) ?(df=Idf) corpus =
  let m = create tf df corpus in
  let tf_fun = term_freq tf in
  let df_fun = doc_freq df in
  _build_with tf_fun df_fun m;
  m


(* iteration function *)

let iteri f m = iteri_lines_of_marshal f m.uri

let mapi f m = mapi_lines_of_marshal f m.uri


(* convert a single document according to a given model *)
let apply m doc =
  (* FIXME *)
  let f t_f d_f n_d = t_f *. log (n_d /. (1. +. d_f))
  in
  let n_d = Owl_nlp_corpus.length m.corpus |> float_of_int in
  let d_f = m.doc_freq in
  let doc = Owl_nlp_corpus.tokenise m.corpus doc in
  let _h = Hashtbl.create 1024 in
  term_count _h doc;
  let tfs = Array.make (Hashtbl.length _h) (0, 0.) in
  let i = ref 0 in
  Hashtbl.iter (fun w t_f ->
    tfs.(!i) <- w, f t_f d_f.(w) n_d;
    i := !i + 1;
  ) _h;
  tfs


(* I/O functions *)

let save m f =
  m.corpus <- Owl_nlp_corpus.reduce_model m.corpus;
  Owl_utils.marshal_to_file m f

let load f : t = Owl_utils.marshal_from_file f


(* ends here *)