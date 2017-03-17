(*
 * OWL - an OCaml numerical library for scientific computing
 * Copyright (c) 2016-2017 Liang Wang <liang.wang@cl.cam.ac.uk>
 *)

(** [ Dataset module provides an easy way to access various datasets for experiment ]  *)

let remote_data_path () = "https://github.com/ryanrhymes/owl_dataset/raw/master/"

let local_data_path () =
  let d = Sys.getenv "HOME" ^ "/owl_dataset/" in
  if Sys.file_exists d = false then (
    Log.info "create %s" d;
    Unix.mkdir d 0o755;
  );
  d

let download_data fname =
  let fn0 = remote_data_path () ^ fname in
  let fn1 = local_data_path () ^ fname in
  let cmd0 = "wget " ^ fn0 ^ " -O " ^ fn1 in
  let cmd1 = "gunzip " ^ fn1 in
  ignore (Sys.command cmd0);
  ignore (Sys.command cmd1)

let download_all () =
  let l = [
    "stopwords.txt.gz"; "enron.test.gz"; "enron.train.gz"; "nips.test.gz"; "nips.train.gz";
    "mnist-test-images.gz"; "mnist-test-labels.gz"; "mnist-test-lblvec.gz";
    "mnist-train-images.gz"; "mnist-train-labels.gz"; "mnist-train-lblvec.gz";
    ] in
  List.iter (fun fname -> download_data fname) l

let load_mnist_train_data () =
  let p = local_data_path () in
  Owl_dense_real.load (p ^ "mnist-train-images"),
  Owl_dense_real.load (p ^ "mnist-train-labels"),
  Owl_dense_real.load (p ^ "mnist-train-lblvec")

let load_mnist_test_data () =
  let p = local_data_path () in
  Owl_dense_real.load (p ^ "mnist-test-images"),
  Owl_dense_real.load (p ^ "mnist-test-labels"),
  Owl_dense_real.load (p ^ "mnist-test-lblvec")

let print_mnist_image x =
  x |> Owl_dense_real.reshape 28 28
  |> Owl_dense_real.iter_rows (fun v ->
    Owl_dense_vector_d.iter (function 0. -> Printf.printf " " | _ -> Printf.printf "■") v;
    print_endline "";
  )

let draw_samples x y n =
  let x, l = Owl_dense_real.draw_rows ~replacement:false x n in
  let y = Owl_dense_real.rows y l in
  x, y