----------------------
Iwahori Hecke Algebras
----------------------

The Iwahori Hecke algebra is defined in [Iwahori1964]_. In that
original paper, the algebra occurs as the convolution ring of
functions on a `p`-adic group that are compactly supported and
invariant both left and right by the Iwahori subgroup. However Iwahori
determined its structure in terms of generators and relations, and it
turns out to be a deformation of the group algebra of the affine Weyl
group.

Once the presentation is found, the Iwahori Hecke algebra can be
defined for any Coxeter group. It depends on a parameter `q` which in
Iwahori's paper is the cardinality of the residue field. But it could
just as easily be an indeterminate.

Then the Iwahori Hecke algebra has the following description. Let
`W` be a Coxeter group, with generators (simple reflections)
`s_1,\dots,s_n`. They satisfy the relations `s_i^2 = 1` and the braid
relations

.. MATH::

    s_i s_j s_i s_j \cdots = s_j s_i s_j s_i \cdots

where the number of terms on each side is the order of `s_i s_j`.

The Iwahori Hecke algebra has a basis `T_1,\dots,T_n` subject to
relations that resemble those of the `s_i`. They satisfy the braid
relations and the quadratic relation

.. MATH::

    (T_i-q)(T_i+1) = 0.

This can be modified by letting `q_1` and `q_2` be two indeterminates
and letting

.. MATH::

    (T_i-q_1)(T_i-q_2) = 0.

In this generality, Iwahori Hecke algebras have significance far
beyond their origin in the representation theory of `p`-adic
groups. For example, they appear in the geometry of Schubert
varieties, where they are used in the definition of the
Kazhdan-Lusztig polynomials. They appear in connection with quantum
groups, and in Jones's original paper on the Jones polynomial.

Here is how to create an Iwahori Hecke algebra::

    sage: R.<q> = PolynomialRing(ZZ)
    sage: H = IwahoriHeckeAlgebraT("B3",q); H
    The Iwahori Hecke Algebra of Type B3 in q,-1 over Univariate
        Polynomial Ring in q over Integer Ring and prefix T
    sage: T1,T2,T3 = H.algebra_generators()
    sage: T1*T1
    (q-1)*T1 + q

If the Cartan type is affine, the generators will be numbered starting
with ``T0`` instead of ``T1``.

You may coerce a Weyl group element into the Iwahori Hecke algebra::

    sage: W = WeylGroup("G2",prefix="s")
    sage: [s1,s2] = W.simple_reflections()
    sage: P.<q> = LaurentPolynomialRing(QQ)
    sage: H = IwahoriHeckeAlgebraT(W,q)
    sage: H(s1*s2)
    T1*T2

