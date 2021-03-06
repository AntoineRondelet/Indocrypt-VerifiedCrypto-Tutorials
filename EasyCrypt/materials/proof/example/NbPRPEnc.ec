require import AllCore SmtMap List Distr.
require import NbEnc QCounter.
require (****) PRPth.

theory NbPRPEnc.

(* Will work for arbitrary types *)
type plaintext.
type nonce = plaintext.
type key.

(* These operators will replace the ones in the PRF theory,
   so our assumption will be based on this function and
   these distributions. *)
op f : key -> nonce -> plaintext.
op dkey : key distr.
op dplaintext : plaintext distr.

(* We bring to the top level the assumptions on the 
   distributions required by the theories we will clone. *)
axiom dkey_ll: is_lossless dkey.
axiom dplaintext_ll: is_lossless dplaintext.
axiom dplaintext_uni: is_uniform dplaintext.
axiom dplaintext_full: is_full dplaintext.

(* Maximal number of queries done by the adversary *)
op q : {int | 0 <= q } as ge0_q.

(* Cloning creates a sub-theory with definitions, 
   axioms and lemmas defined in the cloned theory.
   The <- notation forgets the original type names via
   substitution.
   Using = keeps original names and creates an alias. *)
clone import PRPth with
  type output <- plaintext,
  type key <- key,
  op f <- f,
  op doutput <- dplaintext,
  op dkey <- dkey,
  op q <- q
  (* renaming is purely syntactic on all occurrences! *)
  rename "doutput" as "dplaintext"
  (* if we do not prove axioms in original theory, they
     remain axioms, here we prove all of them under the
     top level axioms above for clarity. *)
  proof *.

realize dplaintext_ll by apply dplaintext_ll.
realize dplaintext_uni by apply dplaintext_uni.
realize dplaintext_full by apply dplaintext_full.
realize dkey_ll by apply dkey_ll.
realize ge0_q by apply ge0_q.

import PRFt.

(* We get the syntax and security definitions for nonce-based
   encryption by copying all the definitions in NbEnc with
   some renamings.
   The alternative = notation adds a type definition
   with an alias.
*)
clone include NbEnc with
  type key <- key,
  type nonce <- nonce,
  type plaintext <- plaintext,
  type ciphertext = plaintext,
  op dciphertext = dplaintext
  proof *.

(* Again we prove all axioms in the underlying theory
   using the top-level ones for clarity *)

realize dciphertext_ll by apply dplaintext_ll.
realize dciphertext_uni by apply dplaintext_uni.
realize dciphertext_full by apply dplaintext_full.

(* XOR operator over plaintexts with minimal properties *)
op (^) : plaintext -> plaintext -> plaintext.

axiom xor_idempotent1 x y : (x ^ y) ^ y = x.
axiom xor_idempotent2 x y : x ^ (x ^ y) = y.

(* Encryption and decryption operators *)
op enc k n p = f k n ^ p.
op dec k n c = f k n ^ c.

(* We prove that decryption recovers an encrypted 
   message using the core logic. This lemma can
   then be used to prove that the scheme is correct. *)
lemma enc_dec_correct k n p :
  dec k n (enc k n p) = p
 by  rewrite /enc /dec xor_idempotent2.

(* The encryption scheme  in the correct syntax. *)
module Scheme : Scheme_T = {

  proc kg () = {
    var k;
    k <$ dkey;
    return k;
  }
  
  proc enc(k:key, n:nonce, p:plaintext) = {
    var mask, c;
    mask <- f k n;
    c <- mask ^ p;
    return c;
  }

  proc dec(k:key, n:nonce, c:ciphertext) = {
    var mask, p;
    mask <- f k n;
    p <- mask ^ c;
    return p;
  }
}.

(*************************************************************)
(*                      CORRECTNESS                          *)
(*************************************************************)


(* We prove partial correctness with respect to the functional
   operators. I.e., correct if terminates.  *)
lemma correct_enc_h k n p :
  hoare [ Scheme.enc : arg = (k,n,p) ==> res = enc k n p]
   by proc; wp; skip; move => /> *; rewrite /enc. 

(* Encryption always terminates *)
lemma correct_enc_ll : islossless Scheme.enc by islossless.

(* Total correctness as a corollary. 
   This means we can always lift any call to
   the enc procedure to a logical operation over its
   inputs *)
lemma correct_enc k n p :
  phoare [ Scheme.enc : arg = (k,n,p) ==> res = enc k n p] = 1%r
  by conseq correct_enc_ll (correct_enc_h k n p). 

(* We do the same for decryption *)
lemma correct_dec_h k n c :
  hoare [ Scheme.dec : arg = (k,n,c) ==> res = dec k n c]
   by proc; wp; skip; move => /> *; rewrite /dec. 

lemma correct_dec_ll : islossless Scheme.dec by islossless.

lemma correct_dec k n c :
  phoare [ Scheme.dec : arg = (k,n,c) ==> res = dec k n c] = 1%r
  by conseq correct_dec_ll (correct_dec_h k n c). 

(* We can apply the above lemmas when we prove that the
   construction is correct as a nonce-based encryption scheme:
   lift encryption and decryption to logical operations and
   then use the fact that the logical operators cancel as
   proved in enc_dec_correct. *)
lemma correctness &m _k _n _p:
  Pr[ Correctness(Scheme).main(_k,_n,_p) @ &m : res ] = 1%r.
byphoare (_: arg = (_k,_n,_p) ==> _) => //.
have lossless: islossless Correctness(Scheme).main; first by islossless.
have correct : hoare [ Correctness(Scheme).main : arg = (_k, _n, _p) ==> res ].
+ proc.
  seq 1 : (#pre /\ c = enc _k _n _p).
  call (correct_enc_h _k _n _p); first by auto => />.
  ecall (correct_dec_h _k _n c). 
  by auto => />; rewrite enc_dec_correct.
by conseq lossless correct. 
qed.

(*************************************************************)
(*                          SECURITY                         *)
(*************************************************************)

(* We must start with a hop where we use the PRP advantage.
   Then we do another hop where we use the PRP_PRF lemma.
   The same generic reduction works.  *)

  module OCPA(O : Orcl) = {
    proc init() = { }

    proc enc (n:nonce, p:plaintext) = {
      var r;
      r <@ O.f(n);
      return (r ^ p);
    }
  }.

module (B(A:AdvCPA):Adv) (O:Orcl) = {
  
  proc guess = CPA(A, OCPA(O)).main

}.

section PROOF.

(*  Declaring an adversary in a section quantifies  universally
    over A for all results in the section. The names in brackets
    indicate that A cannot touch the internal states of these
    modules. Otherwise the proof fails (e.g., A could just get
    the PRF key! *)
declare module A:AdvCPA {CPA, Real_Ideal, Real_PRP, RealScheme, RF, RP, QCounter}.
axiom A_ll (O <: OrclCPA) :  islossless O.enc => islossless A(O).main.

(* We prove equivalences between games using pRHL, which then
   allow us to derive probability results as a consequence.
   These equivalences talk about how events occurring in
   one game relate to events occurring in the other game. *)

(* If PRF game is uses PRF then we are using the real scheme.
   There is a syntactic identity between the games modulo
   renamings. 
   If A starts from the same state, then both games output 
   the same result res and the global counter has the same
   value, so B makes same queries as A. *)
lemma Real_CPA_PRP : 
  equiv [ CPA(A, RealScheme(Scheme)).main ~ Real_Ideal(B(A), Real_PRP).main :
            ={glob A} ==> ={res, QCounter.q} ].
proof.
proc.
 inline *; wp. 
call (: ={CPA.nonces,QCounter.q} /\ RealScheme.k{1} = Real_PRP.k{2}).
by proc; inline *; auto => />  /#.
by auto => />.
qed.

(* We introduce a game hop where we modify the scheme to use
   a true random function instead of the PRF *)
module ModifiedScheme(F : Orcl_i) = {
   include Scheme [-enc,kg]
  
   proc kg() : key = { 
     F.init();
     return witness;
   }

   proc enc(k : key, n : nonce, p : plaintext) : ciphertext = {
    var mask : plaintext;
    var c : ciphertext;
    
    mask <@ F.f(n);
    c <- mask ^ p;
    
    return c;
  }
}.

(* If PRP game uses RP then we are using the modified scheme with RP.
   Again the proof is simply a syntactic match. *)
lemma Modified_CPA_PRP: 
  equiv [ CPA(A, RealScheme(ModifiedScheme(RP))).main ~ Real_Ideal(B(A), Ideal_PRP).main :
            ={glob A} ==> ={res, QCounter.q} ].
proof.
proc; inline *; wp.
call (: ={CPA.nonces,RP.m,QCounter.q}).
+ by proc; inline *;sim.
by auto.
qed.

(* If PRF game uses RF then we are using the modified scheme with RF.
   Again the proof is simply a syntactic match. *)
lemma Modified_CPA_PRF: 
  equiv [ CPA(A, RealScheme(ModifiedScheme(RF))).main ~ Real_Ideal(B(A), Ideal_PRF).main :
            ={glob A} ==> ={res, QCounter.q} ].
proof.
proc; inline *; wp.
call (: ={CPA.nonces,RF.m,QCounter.q}).
+ by proc; inline *;sim.
by auto.
qed.

(* Note that at this point we can apply the PRF_PRP switching lemma *)

lemma modified_prf_prp &m :
      hoare[ Real_Ideal(B(A), Ideal_PRF).main : true ==> QCounter.q <= q] =>
      `|Pr[Real_Ideal(B(A), Ideal_PRF).main() @ &m : res] - 
         Pr[Real_Ideal(B(A), Ideal_PRP).main() @ &m : res]| <=
      (q * (q - 1))%r / 2%r * mu1 dplaintext witness.
proof. 
move => qbound.
apply (prf_prp (B(A)) _ &m qbound). 
+ move => *.
  proc.
  call(_: true).
  move => *.
  + by apply : (A_ll (O0) H0). 
  + by islossless.
  by inline *; auto => />.
qed.

(* Now we do a final step to show we have reached the ideal
   game; we need to argue that the RF acts as a one-time pad
   so ciphertexts do look totally random. *)
lemma Modified_CPA_Ideal:
  equiv [ CPA(A, RealScheme(ModifiedScheme(RF))).main ~ CPA(A, IdealScheme).main :
            ={glob A} ==> ={res, QCounter.q} ].
proof.
proc; inline *; wp.
call (: ={CPA.nonces,QCounter.q} /\
          (forall n, n \in CPA.nonces = n \in RF.m){1}).
+ proc; inline *.
  sp; if; 1, 3: by auto.
  rcondt{1} ^if; 1: by auto => /#.  
  wp. rnd (fun r => r ^ p{1}). 
  auto => />; smt (get_setE xor_idempotent1 dciphertext_uni  dciphertext_full).
by auto => /> *; rewrite mem_empty.
qed.

(* Our main theorem relates advantages of A and B, and it also relates
   the number of queries both make. *)
lemma incpa_security_hop &m:
   hoare[ Real_Ideal(B(A), Ideal_PRF).main : true ==> QCounter.q <= q] =>

   (* Advantages match *)
  `| Pr[CPA(A,RealScheme(Scheme)).main() @ &m : res] - 
       Pr[CPA(A,IdealScheme).main() @ &m : res]| <=
  `| Pr[Real_Ideal(B(A), Real_PRP).main() @ &m : res] - 
       Pr[Real_Ideal(B(A), Ideal_PRP).main() @ &m : res] | +
   (q * (q - 1))%r / 2%r * mu1 dplaintext witness /\

   (* Same number of queries in real games *)
     Pr[CPA(A,RealScheme(Scheme)).main() @ &m : QCounter.q = q ] =
     Pr[Real_Ideal(B(A), Real_PRP).main() @ &m : QCounter.q = q ] /\ 

   (* Same number of queries in ideal games *)
     Pr[CPA(A,IdealScheme).main() @ &m : QCounter.q = q ] =
     Pr[Real_Ideal(B(A), Ideal_PRF).main() @ &m : QCounter.q = q ]
.
proof.
move => qbound.

do split.

(* have -> introduces a new proof goal and immediately rewrites it once
   proved. Here we use the equiv lemmas proved above to rewrite probability
   equalities and wrap up the proof. *)

+ have -> : (Pr[CPA(A,RealScheme(Scheme)).main() @ &m : res] =
            Pr[Real_Ideal(B(A), Real_PRP).main() @ &m : res]); 
     first by byequiv (Real_CPA_PRP) => //.

  have <- : (Pr[CPA(A,RealScheme(ModifiedScheme(RF))).main() @ &m : res] =
            Pr[CPA(A,IdealScheme).main() @ &m : res]); 
     first by byequiv (Modified_CPA_Ideal) => //.

  have -> : (Pr[CPA(A,RealScheme(ModifiedScheme(RF))).main() @ &m : res] =
            Pr[Real_Ideal(B(A), Ideal_PRF).main() @ &m : res]);
     first by  byequiv (Modified_CPA_PRF) => //.

  by move : (modified_prf_prp &m qbound) => /#.

+ have -> : (Pr[CPA(A,RealScheme(Scheme)).main() @ &m : QCounter.q = q] =
            Pr[Real_Ideal(B(A), Real_PRP).main() @ &m : QCounter.q = q]); 
     [ by byequiv (Real_CPA_PRP) => // | by done ].

+ have <- : (Pr[CPA(A,RealScheme(ModifiedScheme(RF))).main() @ &m : QCounter.q = q] =
            Pr[CPA(A,IdealScheme).main() @ &m : QCounter.q = q]); 
     first by byequiv (Modified_CPA_Ideal) => //.

  have <- : (Pr[CPA(A,RealScheme(ModifiedScheme(RF))).main() @ &m : QCounter.q = q] =
            Pr[Real_Ideal(B(A), Ideal_PRF).main() @ &m : QCounter.q = q]); 
     [ by byequiv (Modified_CPA_PRF) => // | by done].

qed.

end section PROOF.

end NbPRPEnc.
