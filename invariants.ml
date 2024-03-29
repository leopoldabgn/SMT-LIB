open Printf

(* Définitions de terme, test et programme *)
type term = 
  | Const of int
  | Var of int
  | Add of term * term
  | Mult of term * term

type test = 
  | Equals of term * term
  | LessThan of term * term

let tt = Equals (Const 0, Const 0)
let ff = LessThan (Const 0, Const 0)
 
type program = {nvars : int; 
                inits : term list; 
                mods : term list; 
                loopcond : test; 
                assertion : test}

let x n = "x" ^ string_of_int n

(* Question 1. Écrire des fonctions `str_of_term : term -> string` 
   et `str_of_test : test -> string` qui convertissent des termes 
   et des tests en chaînes de caractères du format SMTLIB.

  Par exemple, str_of_term (Var 3) retourne "x3", str_of_term (Add
   (Var 1, Const 3)) retourne "(+ x1 3)" et str_of_test (Equals (Var
   2, Const 2)) retourne "(= x2 2)".  *)
let rec str_of_term t = 
  match t with
  | Const c -> string_of_int c
  | Var v -> x v
  | Add  (a, b) -> "(+ " ^ (str_of_term a) ^ " " ^ (str_of_term b) ^ ")"
  | Mult (a, b) ->  "(* " ^ (str_of_term a) ^ " " ^ (str_of_term b) ^ ")"
  

let str_of_test t = 
  match t with
  | Equals (a, b) -> "(= " ^ (str_of_term a) ^ " " ^ (str_of_term b) ^ ")"
  | LessThan (a, b) -> "(< " ^ (str_of_term a) ^ " " ^ (str_of_term b) ^ ")"

let string_repeat s n =
  Array.fold_left (^) "" (Array.make n s)

(* Question 2. Écrire une fonction `str_condition : term list -> string`
   qui prend une liste de termes t1, ..., tk et retourne une chaîne 
   de caractères qui exprime que le tuple (t1, ..., tk) est dans 
   l'invariant.  Par exemple, str_condition [Var 1; Const 10] retourne 
   "(Inv x1 10)".
*)
let str_condition l =
  (* On fait un map pour transformer tous les `term` de la liste en string *)
  let term_list = List.map (str_of_term) l in
  (* - l est la liste des éléments qu'on va retirer au fur et à mesure
     - res est la string qu'on va modifier et qui representera le resultat final*)
  let rec str_condition_aux l res =
    match l with
    | [] -> res ^ ")"
    | term :: sublist -> str_condition_aux sublist (res ^ " " ^ term)
  (* La string res contient un "(Inv" au début puis on rajoutera un ")" à la fin *)
  in str_condition_aux term_list "(Invar"

(* Question 3. Écrire une fonction 
   `str_assert_for_all : int -> string -> string` qui prend en
   argument un entier n et une chaîne de caractères s, et retourne
   l'expression SMTLIB qui correspond à la formule "forall x1 ... xk
              (s)".

  Par exemple, str_assert_forall 2 "< x1 x2" retourne : "(assert
                                                             (forall ((x1 Int) (x2 Int)) (< x1 x2)))".  *)

let str_assert s = "(assert " ^ s ^ ")"

(* Permet de convertir un int en string `(i Int)` *)
let str_int i = "(" ^ (string_of_int i) ^ " Int)"
                  
let str_assert_forall n s = 
  (* Ici, nous avons:
     - res, la string avec le résultat qu'on renverra à la fin.
     - index qu'on va incrementer jusqu'à arriver à max *)
  let rec str_forall_aux res index max =
    match index with
    | i when i = max -> res
    | i -> let res = if i > 0 then res ^ " " else res in (* On ajoute un espace avant que après le 1er appel. (Pour pas avoir un espace en trop au début) *)
        str_forall_aux (res ^ ("(" ^ (x (index+1)) ^ " Int)")) (i+1) max (* On concatène (index Int) à notre résultat*)
  in let s = " (" ^ s ^ ")" in
  str_assert ((str_forall_aux "\n(forall (" 0 n) ^ ")" ^ s ^ ")") (* Pour finir, on ajoute (assert ... et (forall... *)

(* Question 4. Nous donnons ci-dessous une définition possible de la
   fonction smt_lib_of_wa. Complétez-la en écrivant les définitions de
   loop_condition et assertion_condition. *)

(* Une fonction permettant de créer une liste de n variables  *)
let tab_of_vars n = 
  let rec tab_of_vars_aux ni list =
    match ni with
    | 0 -> list
    | _ -> tab_of_vars_aux (ni-1) (Var ni :: list)
  in tab_of_vars_aux n []

(* Fonction permettant d'obtenir la negation de la fonction str_of_test, utile pour obtenir 
   la négation d'une condition de boucle *)
let negation_of_str_of_test t = 
  match t with 
  |Equals(x,y)->"(not ("^(str_of_term x)^" "^(str_of_term y)^"))"
  |LessThan(x,y)-> "(>= "^(str_of_term x)^" "^(str_of_term y)^")"

let smtlib_of_wa p = 
  let declare_invariant n =
    "; synthèse d'invariant de programme\n"
    ^"; on déclare le symbole non interprété de relation Invar\n"
    ^"(declare-fun Invar (" ^ string_repeat "Int " n ^  ") Bool)" in
  let loop_condition p =
    "; la relation Invar est un invariant de boucle\n"
    ^str_assert_forall p.nvars ("\n => (and "^str_condition (tab_of_vars p.nvars)^" "
    ^str_of_test p.loopcond ^ ") " ^ str_condition p.mods) in
  let initial_condition p =
    "; la relation Invar est vraie initialement\n"
    ^str_assert (str_condition p.inits) in
  let assertion_condition p =
    "; l'assertion finale est vérifiée\n"
    ^str_assert_forall p.nvars ("\n => (and " ^ str_condition (tab_of_vars p.nvars)^ " "
    ^ negation_of_str_of_test p.loopcond ^ ") " ^ str_of_test p.assertion) in
  let call_solver =
    "; appel au solveur\n(check-sat-using (then qe smt))\n(get-model)\n(exit)\n" in
  String.concat "\n" [declare_invariant p.nvars;
                      loop_condition p;
                      initial_condition p;
                      assertion_condition p;
                      call_solver]

let p1 = {nvars = 2;
          inits = [(Const 0) ; (Const 0)];
          mods = [Add ((Var 1), (Const 1)); Add ((Var 2), (Const 3))];
          loopcond = LessThan ((Var 1),(Const 3));
          assertion = Equals ((Var 2),(Const 9))}


let () = Printf.printf "%s" (smtlib_of_wa p1)

(* Question 5. Vérifiez que votre implémentation donne un fichier
   SMTLIB qui est équivalent au fichier que vous avez écrit à la main
   dans l'exercice 1. Ajoutez dans la variable p2 ci-dessous au moins
   un autre programme test, et vérifiez qu'il donne un fichier SMTLIB
   de la forme attendue. *)

let p2 = {nvars = 2;
          inits = [(Const 1) ; (Const 1)];
          mods = [Add ((Var 1), (Const 3)) ; Mult ((Var 2), (Const 5))];
          loopcond = LessThan ((Var 2),(Const 10));
          assertion = Equals ((Var 1),(Const 7))}

let () = Printf.printf "\n\n\n"


let () = Printf.printf "%s" (smtlib_of_wa p2)

