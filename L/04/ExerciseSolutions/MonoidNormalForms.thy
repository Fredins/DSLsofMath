theory MonoidNormalForms
  imports Main
begin

(* This is a formalization of the monoid simplification we discussed
   in the exercises in the proof assistant Isabelle. Isabelle checks
   that steps in a proof are valid, so one no longer has to
   trust individual steps in a proof, just that the data types, functions
   and theorem statements make sense. *)

(* NOTE: this file is just here for people who are interested in how
   normal pen-and-paper proofs look like in proof assistants that
   mechanically check the correctness of proofs. Understanding Isabelle code
   is NOT required for the exam. *)

(* Isabelle code is somewhat similar to Haskell with a few differences:
  - : for lists is #
  - ++ is @
  - type parameters are passed as prefix arguments to parametric types, e.g. int list instead of
    list int.
The proof syntax resembles pen-and-paper proofs, so it should be readable without
any exposure to Isabelle. You can ignore lines starting with by <something-long>,
which are generated by automated tools. "by simp" or "by auto" basically shows
that a step is trivial enough for the basic automation of Isabelle to show them.

Note that the proofs here are much longer than they need to be to show the
reasoning in more detail. Many steps could be solved by automated tools instead.
*)


(* We assume that we have some type of variables: *)
typedecl var

(* for simplicity, we assume that var is countably infinite: *)
consts
  \<V> :: "var \<Rightarrow> nat"
axiomatization where
  var_countable: "\<And> x y. \<V> x = \<V> y  \<Longrightarrow> x = y"

(* This datatype encodes monoid expressions: *)
datatype Monoid = One | Var var | Plus Monoid Monoid

fun simpl :: "Monoid \<Rightarrow> var list" where
  "simpl One = []" |
  "simpl (Var x) = [x]"  |
  "simpl (Plus e\<^sub>1 e\<^sub>2) = simpl e\<^sub>1 @ simpl e\<^sub>2"


(* For simplicity, we model the Monoid type class using
   a record with two elements, and some nicer syntax for it. *)
record 'a monoid =
  mult    :: "['a, 'a] \<Rightarrow> 'a" (infixl "\<otimes>\<index>" 70)
  one     :: 'a ("\<one>\<index>")

(* Note that we need to write \<one>\<^bsub>M\<^esub> for some monoid M to indicate which
   monoid's "\<one>" we want to use. Similarly for \<otimes> *)


(* We also define what it to be a valid monoid instance: *)
definition is_monoid :: "'a monoid \<Rightarrow> bool" where
  "is_monoid M \<equiv> (\<forall> e. \<one>\<^bsub>M\<^esub> \<otimes>\<^bsub>M\<^esub> e = e \<and> e \<otimes>\<^bsub>M\<^esub> \<one>\<^bsub>M\<^esub> = e) \<and>
                 (\<forall> x y z. (x \<otimes>\<^bsub>M\<^esub> y) \<otimes>\<^bsub>M\<^esub> z = x \<otimes>\<^bsub>M\<^esub> (y \<otimes>\<^bsub>M\<^esub> z))"


(* Evaluation then looks like in Haskell *)
fun eval :: "'a monoid \<Rightarrow> (var \<Rightarrow> 'a) \<Rightarrow> Monoid \<Rightarrow> 'a" where
  "eval M env One = \<one>\<^bsub>M\<^esub>" |
  "eval M env (Plus a b) = eval M env a \<otimes>\<^bsub>M\<^esub> eval M env b" |
  "eval M env (Var x) = env x"


(* We can also define evaluation for simplified expressions: *)
fun eval' :: "'a monoid \<Rightarrow> (var \<Rightarrow> 'a) \<Rightarrow> var list \<Rightarrow> 'a" where
  "eval' M env [] = \<one>\<^bsub>M\<^esub>" |
  "eval' M env (x # xs) = env x \<otimes>\<^bsub>M\<^esub> eval' M env xs"

(* A trivial helper lemma showing that appending lists in eval' and \<otimes> commute;
   this follows immediately from induction on xs: *)
lemma eval'_app:
  assumes is_mon: "is_monoid M"
  shows "eval' M env (xs @ ys) = eval' M env xs \<otimes>\<^bsub>M\<^esub> eval' M env ys"
  using is_mon by (induction xs, auto simp: is_monoid_def)

lemma preserves_semantics:
  assumes is_mon: "is_monoid M"
  shows "eval' M env (simpl e) = eval M env e"
  using assms
  unfolding is_monoid_def
proof (induction e)
  case One
  then show ?case 
    by simp
next
  case (Var x)
  then show ?case
    by auto
next
  case (Plus e1 e2)
  then show ?case 
    using assms eval'_app
    by (simp add: eval'_app)
qed

(* Two expressions are equal in some monoid M, if they always
  evaluate to the same value for any environment: *)
definition exps_equiv :: "'a monoid \<Rightarrow> Monoid \<Rightarrow> Monoid \<Rightarrow> bool" 
  (infix "\<approx>\<index>" 60) where
  "e\<^sub>1 \<approx>\<^bsub>M\<^esub> e\<^sub>2 \<equiv> (\<forall> env. eval M env e\<^sub>1 = eval M env e\<^sub>2)"

(* The list monoid is just a record with append and the empty list
   for \<otimes> and \<one>: *)
definition list_monoid :: "'a list monoid" where
  "list_monoid \<equiv> \<lparr> mult = (op @) , one = [] \<rparr>"

(* It's a monoid: *)
lemma list_monoid_is_monoid:
  "is_monoid list_monoid"
  unfolding is_monoid_def list_monoid_def
  by auto

(* We specialize the element type of the list to nat for later: *)
definition list_monoid_nat :: "nat list monoid" where
  "list_monoid_nat = list_monoid"

(* We now define an environment that, if we evaluate a monoid expression in it,
   we don't lose any information. We know that we can build such an environment
   from the assumption that var is countably infinite *)
definition env\<^sub>U :: "var \<Rightarrow> nat list" where
  "env\<^sub>U x = [\<V> x]"

(* Since we don't want to manually unfold the definitions
   for the list monoid, we tell the simplifier to do this
   automatically. *)
declare list_monoid_nat_def[simp] list_monoid_def[simp]

(* We can show that evaluating the simplified expression is of the same
  length as the input list. This is fairly easy and could be solved
  by (induction xs, auto), but to show how this works, we can write out
  the proof in detail: *)
lemma length_sim:
  "length (eval' list_monoid_nat env\<^sub>U xs) = length xs"
proof (induction xs)
  case Nil (* Here we have an empty list: *)
  hence "length [] = 0" by simp
  (* Simplifying the empty list gives us an empty list, by
     unfolding the definition of the list monoid. *)
  moreover have "eval' list_monoid_nat env\<^sub>U [] = []" 
    by simp
  ultimately show ?case by simp
next
  (* In the other case we have that the list has one element
     x followed by list xs: *)
  case (Cons x xs)
  (* We get from the induction hypothesis, we have that
     the length of xs is the same as when evaluating xs: *)
  then have "length xs = length (eval' list_monoid_nat env\<^sub>U xs)"
    by simp 
  (* Then adding an element in front of both will not change the length,
     because env\<^sub>U by definition only returns singletons. *)
  then show ?case 
    unfolding env\<^sub>U_def
    by simp
qed

(* Now we prove that we can "simulate" evaluating an expression
   without losing information: *)
lemma eval_sim:
  "i < length xs \<Longrightarrow> eval' list_monoid_nat env\<^sub>U xs ! i = \<V> (xs ! i)"
proof (induction xs arbitrary: i) (* Again we use induction on xs. *)
  case Nil
  (* There's no i such that i < length [] = 0, so this is trivial: *)
  then show ?case 
    by simp
next
  case (Cons x xs) (* This names the induction hypothesis 'Cons': *)
  (* We can show this case by distinction on whether i is 0 or not: *)
  then show ?case
  proof (cases "i")
    case 0 (* This case follows trivially from the definition of eval' and env\<^sub>U *)
    with env\<^sub>U_def show ?thesis
      by simp
  next
    case (Suc j) (* Here i = j + 1 for some j. Then the claim follows from the induction
    hypothesis, because it taking the ith element in (x # xs) will give the jth element
    in xs, since env\<^sub>U returns single-element lists *)
    with Cons show ?thesis 
      unfolding env\<^sub>U_def
      by simp
  qed
qed
 
(* Now we can proceed to the main proof:
- Since Isabelle/HOL doesn't support quantifying over types, we 
  specialize the equivalence assumption to the monoid for lists of natural numbers: *)
lemma simpl_unique:
  assumes eqv: "e \<approx>\<^bsub>list_monoid_nat\<^esub> e'"
  shows "simpl e = simpl e'"
proof -
  (* Some shorthands: *)
  let ?e = "simpl e"
  let ?e' = "simpl e'" 
  show ?thesis
  proof (rule ccontr)
    assume neq: "simpl e \<noteq> simpl e'"
    have "length ?e = length ?e'"
    proof (rule ccontr)
      assume "length ?e \<noteq> length ?e'"
      (* Using eval_sim, this implies that the two unsimplified expressions also
         differ in length: *)
      with preserves_semantics have
        "length (eval list_monoid_nat env\<^sub>U e) = length (eval' list_monoid_nat env\<^sub>U (simpl e))"
        by (metis list_monoid_is_monoid list_monoid_nat_def)
      moreover with length_sim have
        "length (eval list_monoid_nat env\<^sub>U e) \<noteq> length (eval list_monoid_nat env\<^sub>U e')"
        by (metis \<open>length (simpl e) \<noteq> length (simpl e')\<close> list_monoid_is_monoid list_monoid_nat_def preserves_semantics)
      moreover from preserves_semantics have
        "length (eval list_monoid_nat env\<^sub>U e') = length (eval' list_monoid_nat env\<^sub>U (simpl e'))"
        by (metis list_monoid_is_monoid list_monoid_nat_def)
      ultimately show False 
        using length_sim
        by (metis eqv exps_equiv_def)
    qed
    (* Since the lengths are equal, we there must be at least one index i where they differ: *)
    with neq obtain i where in_list: "i < length ?e" and
      diff: "?e ! i \<noteq> ?e' ! i"
      using nth_equalityI by blast
    let ?x = "?e ! i"
    let ?y = "?e' ! i"
    (* We have that looking up i in the unsimplified expression
       is the same as in the simplified one. *)
    from preserves_semantics have
      "eval list_monoid_nat env\<^sub>U e ! i =
       eval' list_monoid_nat env\<^sub>U ?e ! i"
      by (metis list_monoid_is_monoid list_monoid_nat_def)
    (* The simplification lemma tells us that this is the same as applying \<V> to the variable
       at that index: *)
    moreover have "eval' list_monoid_nat env\<^sub>U ?e ! i = \<V> ?x"
      using \<open>i < length (simpl e)\<close> eval_sim by blast
    (* By assumption this is different from the variable in e' at i: *)
    moreover from diff have "\<V> (?e ! i) \<noteq> \<V> (?e' ! i)"
      using var_countable by auto
    (* Analogously to before we know that this is the same as evaluating the unsimplified
       expressions. *)
    moreover hence "\<V> (?e' ! i) = eval list_monoid_nat env\<^sub>U e ! i"
      by (metis eqv eval_sim exps_equiv_def in_list length_sim list_monoid_is_monoid list_monoid_nat_def preserves_semantics)
    (* This means the evaluation results are different, at least at i, contradiction
       our equivalence assumption: *)
    ultimately show False
      by linarith
  qed
qed

end
