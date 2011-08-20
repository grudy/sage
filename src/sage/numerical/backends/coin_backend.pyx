"""
COIN Backend

AUTHORS:

- Nathann Cohen (2010-10): initial implementation
"""

##############################################################################
#       Copyright (C) 2010 Nathann Cohen <nathann.cohen@gmail.com>
#  Distributed under the terms of the GNU General Public License (GPL)
#  The full text of the GPL is available at:
#                  http://www.gnu.org/licenses/
##############################################################################


from sage.numerical.mip import MIPSolverException

cdef class CoinBackend(GenericBackend):

    def __cinit__(self, maximization = True):

        self.si = new_c_OsiCbcSolverInterface();
        # stuff related to the loglevel
        cdef c_CbcModel * model
        model = self.si.getModelPtr()

        import multiprocessing
        model.setNumberThreads(multiprocessing.cpu_count())

        self.set_verbosity(0)

        if maximization:
            self.set_sense(+1)
        else:
            self.set_sense(-1)

    cpdef int add_variable(self, lower_bound=0.0, upper_bound=None, binary=False, continuous=False, integer=False, obj=0.0, name=None) except -1:
        """
        Add a variable.

        This amounts to adding a new column to the matrix. By default,
        the variable is both positive and real.

        INPUT:

        - ``lower_bound`` - the lower bound of the variable (default: 0)

        - ``upper_bound`` - the upper bound of the variable (default: ``None``)

        - ``binary`` - ``True`` if the variable is binary (default: ``False``).

        - ``continuous`` - ``True`` if the variable is binary (default: ``True``).

        - ``integer`` - ``True`` if the variable is binary (default: ``False``).

        - ``obj`` - (optional) coefficient of this variable in the objective function (default: 0.0)

        - ``name`` - an optional name for the newly added variable (default: ``None``).

        OUTPUT: The index of the newly created variable

        .. NOTE::

            The names are ignored by Coin at the moment !!!

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")                  # optional - Coin
            sage: p.ncols()                                         # optional - Coin
            0
            sage: p.add_variable()                                  # optional - Coin
            0
            sage: p.ncols()                                         # optional - Coin
            1
            sage: p.add_variable(binary=True)                       # optional - Coin
            1
            sage: p.add_variable(lower_bound=-2.0, integer=True)    # optional - Coin
            2
            sage: p.add_variable(continuous=True, integer=True)     # optional - Coin
            Traceback (most recent call last):
            ...
            ValueError: ...
            sage: p.add_variable(name='x',obj=1.0)                  # optional - Coin
            3
            sage: p.col_name(3)                                     # optional - Coin
            ''
            sage: p.objective_coefficient(3)                        # optional - Coin
            1.0

        """

        cdef int vtype = int(bool(binary)) + int(bool(continuous)) + int(bool(integer))
        if  vtype == 0:
            continuous = True
        elif vtype != 1:
            raise ValueError("Exactly one parameter of 'binary', 'integer' and 'continuous' must be 'True'.")

        self.si.addCol(0, NULL, NULL, 0, self.si.getInfinity(), 0)

        cdef int n
        n = self.si.getNumCols() - 1

        if lower_bound != 0.0:
            self.variable_lower_bound(n, lower_bound)
        if upper_bound is not None:
            self.variable_upper_bound(n, upper_bound)

        if binary:
            self.set_variable_type(n,0)
        elif integer:
            self.set_variable_type(n,1)

        # THE NAMES ARE IGNORED BY COIN AT THE MOMENT

        if obj:
            self.si.setObjCoeff(n, obj)

        return n

    cpdef int add_variables(self, int number, lower_bound=0.0, upper_bound=None, binary=False, continuous=False, integer=False, obj=0.0, names=None) except -1:
        """
        Add ``number`` new variables.

        This amounts to adding new columns to the matrix. By default,
        the variables are both positive and real.

        INPUT:

        - ``n`` - the number of new variables (must be > 0)

        - ``lower_bound`` - the lower bound of the variable (default: 0)

        - ``upper_bound`` - the upper bound of the variable (default: ``None``)

        - ``binary`` - ``True`` if the variable is binary (default: ``False``).

        - ``continuous`` - ``True`` if the variable is binary (default: ``True``).

        - ``integer`` - ``True`` if the variable is binary (default: ``False``).

        - ``obj`` - (optional) coefficient of all variables in the objective function (default: 0.0)

        - ``names`` - optional list of names (default: ``None``)

        OUTPUT: The index of the variable created last.

        .. NOTE::

            The names are ignored by Coin at the moment !!!

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")                         # optional - Coin
            sage: p.ncols()                                                # optional - Coin
            0
            sage: p.add_variables(5)                                       # optional - Coin
            4
            sage: p.ncols()                                                # optional - Coin
            5
            sage: p.add_variables(2, lower_bound=-2.0, integer=True, names=['a','b']) # optional - Coin
            6
        """
        cdef int vtype = int(bool(binary)) + int(bool(continuous)) + int(bool(integer))
        if  vtype == 0:
            continuous = True
        elif vtype != 1:
            raise ValueError("Exactly one parameter of 'binary', 'integer' and 'continuous' must be 'True'.")

        cdef int n
        n = self.si.getNumCols()

        cdef int i

        for 0<= i < number:

            self.si.addCol(0, NULL, NULL, 0, self.si.getInfinity(), 0)

            if lower_bound != 0.0:
                self.variable_lower_bound(n + i, lower_bound)
            if upper_bound is not None:
                self.variable_upper_bound(n + i, upper_bound)

            if binary:
                self.set_variable_type(n + i,0)
            elif integer:
                self.set_variable_type(n + i,1)

            if obj:
                self.si.setObjCoeff(n + i, obj)

        # THE NAMES ARE IGNORED BY COIN AT THE MOMENT

        return n + number -1

    cpdef set_variable_type(self, int variable, int vtype):
        r"""
        Sets the type of a variable

        INPUT:

        - ``variable`` (integer) -- the variable's id

        - ``vtype`` (integer) :

            *  1  Integer
            *  0  Binary
            * -1 Real

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")   # optional - Coin
            sage: p.ncols()                                        # optional - Coin
            0
            sage: p.add_variable()                                  # optional - Coin
            0
            sage: p.set_variable_type(0,1)                          # optional - Coin
            sage: p.is_variable_integer(0)                          # optional - Coin
            True
        """

        if vtype == 1:
            self.si.setInteger(variable)
        elif vtype == 0:
            self.si.setColLower(variable, 0)
            self.si.setInteger(variable)
            self.si.setColUpper(variable, 1)
        else:
            self.si.setContinuous(variable)

    cpdef set_sense(self, int sense):
        r"""
        Sets the direction (maximization/minimization).

        INPUT:

        - ``sense`` (integer) :

            * +1 => Maximization
            * -1 => Minimization

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.is_maximization()                              # optional - Coin
            True
            sage: p.set_sense(-1)                              # optional - Coin
            sage: p.is_maximization()                              # optional - Coin
            False
        """
        self.si.setObjSense(-sense)

    cpdef objective_coefficient(self, int variable, coeff=None):
        """
        Set or get the coefficient of a variable in the objective function

        INPUT:

        - ``variable`` (integer) -- the variable's id

        - ``coeff`` (double) -- its coefficient or ``None`` for
          reading (default: ``None``)

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")       # optional -- Coin
            sage: p.add_variable()                      # optional -- Coin
            0
            sage: p.objective_coefficient(0)            # optional -- Coin
            0.0
            sage: p.objective_coefficient(0,2)          # optional -- Coin
            sage: p.objective_coefficient(0)            # optional -- Coin
            2.0
        """
        if coeff is not None:
            self.si.setObjCoeff(variable, coeff)
        else:
            return self.si.getObjCoefficients()[variable]

    cpdef set_objective(self, list coeff):
        r"""
        Sets the objective function.

        INPUT:

        - ``coeff`` -- a list of real values, whose ith element is the
          coefficient of the ith variable in the objective function.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")    # optional - Coin
            sage: p.add_variables(5)                                 # optional - Coin
            4
            sage: p.set_objective([1, 1, 2, 1, 3])                   # optional - Coin
            sage: map(lambda x :p.objective_coefficient(x), range(5))  # optional - Coin
            [1.0, 1.0, 2.0, 1.0, 3.0]
        """

        cdef int i
        for i,v in enumerate(coeff):
            self.si.setObjCoeff(i, v)

    cpdef set_verbosity(self, int level):
        r"""
        Sets the log (verbosity) level

        INPUT:

        - ``level`` (integer) -- From 0 (no verbosity) to 3.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")   # optional - Coin
            sage: p.set_verbosity(2)                                # optional - Coin

        """

        cdef c_CbcModel * model
        cdef c_CoinMessageHandler * msg
        model = self.si.getModelPtr()
        msg = model.messageHandler()
        msg.setLogLevel(level)

    cpdef add_linear_constraints(self, int number, lower_bound, upper_bound, names = None):
        """
        Add ``'number`` linear constraints.

        INPUT:

        - ``number`` (integer) -- the number of constraints to add.

        - ``lower_bound`` - a lower bound, either a real value or ``None``

        - ``upper_bound`` - an upper bound, either a real value or ``None``

        - ``names`` - an optional list of names (default: ``None``)

        .. NOTE::

            The names are ignored by Coin at the moment !!!

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")        # optional - Coin
            sage: p.add_variables(5)                     # optional - Coin
            4
            sage: p.add_linear_constraints(5, None, 2)   # optional - Coin
            sage: p.row(4)                               # optional - Coin
            ([], [])
            sage: p.row_bounds(4)                        # optional - Coin
            (None, 2.0)
            sage: p.add_linear_constraints(2, None, 2, names=['foo','bar']) # optional - Coin
        """

        cdef int i
        for 0<= i<number:
            self.add_linear_constraint([],lower_bound, upper_bound)

    cpdef add_linear_constraint(self, coefficients, lower_bound, upper_bound, name = None):
        """
        Add a linear constraint.

        INPUT:

        - ``coefficients`` an iterable with ``(c,v)`` pairs where ``c``
          is a variable index (integer) and ``v`` is a value (real
          value).

        - ``lower_bound`` - a lower bound, either a real value or ``None``

        - ``upper_bound`` - an upper bound, either a real value or ``None``

        - ``name`` - an optional name for this row (default: ``None``)

        .. NOTE::

            The names are ignored by Coin at the moment !!!

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")                              # optional - Coin
            sage: p.add_variables(5)                                           # optional - Coin
            4
            sage: p.add_linear_constraint( zip(range(5), range(5)), 2.0, 2.0)  # optional - Coin
            sage: p.row(0)                                                     # optional - Coin
            ([0, 1, 2, 3, 4], [0.0, 1.0, 2.0, 3.0, 4.0])
            sage: p.row_bounds(0)                                              # optional - Coin
            (2.0, 2.0)
            sage: p.add_linear_constraint( zip(range(5), range(5)), 1.0, 1.0, name='foo') # optional - Coin
            sage: p.row_name(1)                                                           # optional - Coin
            ''

        """
        if lower_bound is None and upper_bound is None:
            raise ValueError("At least one of 'upper_bound' or 'lower_bound' must be set.")

        cdef int i
        cdef double c
        cdef c_CoinPackedVector* row
        row = new_c_CoinPackedVector();


        for i,c in coefficients:
            row.insert(i, c)

        self.si.addRow (row[0],
                        lower_bound if lower_bound != None else -self.si.getInfinity(),
                        upper_bound if upper_bound != None else +self.si.getInfinity())

    cpdef row(self, int index):
        r"""
        Returns a row

        INPUT:

        - ``index`` (integer) -- the constraint's id.

        OUTPUT:

        A pair ``(indices, coeffs)`` where ``indices`` lists the
        entries whose coefficient is nonzero, and to which ``coeffs``
        associates their coefficient on the model of the
        ``add_linear_constraint`` method.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.add_variables(5)                               # optional - Coin
            4
            sage: p.add_linear_constraint(zip(range(5), range(5)), 2, 2)       # optional - Coin
            sage: p.row(0)                                     # optional - Coin
            ([0, 1, 2, 3, 4], [0.0, 1.0, 2.0, 3.0, 4.0])
            sage: p.row_bounds(0)                              # optional - Coin
            (2.0, 2.0)
        """

        cdef list indices = []
        cdef list values = []
        cdef int * c_indices
        cdef int i
        cdef double * c_values
        cdef c_CoinPackedMatrix * M = <c_CoinPackedMatrix *> self.si.getMatrixByRow()
        cdef c_CoinShallowPackedVector V = <c_CoinShallowPackedVector> M.getVector(index)
        cdef int n = V.getNumElements()

        c_indices = <int*> V.getIndices()
        c_values = <double*> V.getElements()

        for 0<= i < n:
            indices.append(c_indices[i])
            values.append(c_values[i])

        return (indices, values)

    cpdef row_bounds(self, int i):
        r"""
        Returns the bounds of a specific constraint.

        INPUT:

        - ``index`` (integer) -- the constraint's id.

        OUTPUT:

        A pair ``(lower_bound, upper_bound)``. Each of them can be set
        to ``None`` if the constraint is not bounded in the
        corresponding direction, and is a real value otherwise.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.add_variables(5)                               # optional - Coin
            4
            sage: p.add_linear_constraint(zip(range(5), range(5)), 2, 2)       # optional - Coin
            sage: p.row(0)                                     # optional - Coin
            ([0, 1, 2, 3, 4], [0.0, 1.0, 2.0, 3.0, 4.0])
            sage: p.row_bounds(0)                              # optional - Coin
            (2.0, 2.0)
        """

        cdef double * ub
        cdef double * lb

        ub = <double*> self.si.getRowUpper()
        lb = <double*> self.si.getRowLower()

        return (lb[i] if lb[i] != - self.si.getInfinity() else None,
                ub[i] if ub[i] != + self.si.getInfinity() else None)

    cpdef col_bounds(self, int i):
        r"""
        Returns the bounds of a specific variable.

        INPUT:

        - ``index`` (integer) -- the variable's id.

        OUTPUT:

        A pair ``(lower_bound, upper_bound)``. Each of them can be set
        to ``None`` if the variable is not bounded in the
        corresponding direction, and is a real value otherwise.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.add_variable()                                 # optional - Coin
            0
            sage: p.col_bounds(0)                              # optional - Coin
            (0.0, None)
            sage: p.variable_upper_bound(0, 5)                         # optional - Coin
            sage: p.col_bounds(0)                              # optional - Coin
            (0.0, 5.0)
        """

        cdef double * ub
        cdef double * lb

        ub = <double*> self.si.getColUpper()
        lb = <double*> self.si.getColLower()

        return (lb[i] if lb[i] != - self.si.getInfinity() else None,
                ub[i] if ub[i] != + self.si.getInfinity() else None)

    cpdef add_col(self, list indices, list coeffs):
        r"""
        Adds a column.

        INPUT:

        - ``indices`` (list of integers) -- this list constains the
          indices of the constraints in which the variable's
          coefficient is nonzero

        - ``coeffs`` (list of real values) -- associates a coefficient
          to the variable in each of the constraints in which it
          appears. Namely, the ith entry of ``coeffs`` corresponds to
          the coefficient of the variable in the constraint
          represented by the ith entry in ``indices``.

        .. NOTE::

            ``indices`` and ``coeffs`` are expected to be of the same
            length.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.ncols()                                       # optional - Coin
            0
            sage: p.nrows()                                       # optional - Coin
            0
            sage: p.add_linear_constraints(5, 0, None)                      # optional - Coin
            sage: p.add_col(range(5), range(5))                    # optional - Coin
            sage: p.nrows()                                       # optional - Coin
            5
        """

        cdef int n = len(indices)
        cdef int * c_indices = <int*>sage_malloc(n*sizeof(int))
        cdef double * c_values  = <double*>sage_malloc(n*sizeof(double))
        cdef int i

        for 0<= i< n:
            c_indices[i] = indices[i]
            c_values[i] = coeffs[i]


        self.si.addCol (1, c_indices, c_values, 0, self.si.getInfinity(), 0)

    cpdef int solve(self) except -1:
        r"""
        Solves the problem.

        .. NOTE::

            This method raises ``MIPSolverException`` exceptions when
            the solution can not be computed for any reason (none
            exists, or the LP solver was not able to find it, etc...)

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")    # optional - Coin
            sage: p.add_linear_constraints(5, 0, None)       # optional - Coin
            sage: p.add_col(range(5), [1,2,3,4,5])  # optional - Coin
            sage: p.solve()                         # optional - Coin
            0

        TESTS::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")    # optional - Coin
            sage: p.add_variable()                  # optional - Coin
            0
            sage: p.add_linear_constraint([(0, 1)], None, 4) # optional - Coin
            sage: p.add_linear_constraint([(0, 1)], 6, None) # optional - Coin
            sage: p.objective_coefficient(0,1)        # optional - Coin
            sage: p.solve()                         # optional - Coin
            Traceback (most recent call last):
            ...
            MIPSolverException: ...
        """

        self.si.branchAndBound()

        cdef const_double_ptr solution

        if self.si.isAbandoned():
            raise MIPSolverException("CBC : The solver has abandoned!")

        elif self.si.isProvenPrimalInfeasible() or self.si.isProvenDualInfeasible():
            raise MIPSolverException("CBC : The problem or its dual has been proven infeasible!")

        elif (self.si.isPrimalObjectiveLimitReached() or self.si.isDualObjectiveLimitReached()):
            raise MIPSolverException("CBC : The objective limit has been reached for the problem or its dual!")

        elif self.si.isIterationLimitReached():
            raise MIPSolverException("CBC : The iteration limit has been reached!")

        elif not self.si.isProvenOptimal():
            raise MIPSolverException("CBC : Unknown error")

    cpdef double get_objective_value(self):
        r"""
        Returns the value of the objective function.

        .. NOTE::

           Has no meaning unless ``solve`` has been called before.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.add_variables(2)                               # optional - Coin
            1
            sage: p.add_linear_constraint([(0, 1), (1, 2)], None, 3)          # optional - Coin
            sage: p.set_objective([2, 5])                          # optional - Coin
            sage: p.solve()                                        # optional - Coin
            0
            sage: p.get_objective_value()                          # optional - Coin
            7.5
            sage: p.get_variable_value(0)                          # optional - Coin
            0.0
            sage: p.get_variable_value(1)                          # optional - Coin
            1.5
        """

        return self.si.getObjValue()

    cpdef double get_variable_value(self, int variable):
        r"""
        Returns the value of a variable given by the solver.

        .. NOTE::

           Has no meaning unless ``solve`` has been called before.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin") # optional - Coin
            sage: p.add_variables(2)                              # optional - Coin
            1
            sage: p.add_linear_constraint([(0, 1), (1, 2)], None, 3)          # optional - Coin
            sage: p.set_objective([2, 5])                         # optional - Coin
            sage: p.solve()                                       # optional - Coin
            0
            sage: p.get_objective_value()                         # optional - Coin
            7.5
            sage: p.get_variable_value(0)                         # optional - Coin
            0.0
            sage: p.get_variable_value(1)                         # optional - Coin
            1.5
        """

        cdef double * solution
        solution = <double*> self.si.getColSolution()
        return solution[variable]

    cpdef int ncols(self):
        r"""
        Returns the number of columns/variables.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.ncols()                                       # optional - Coin
            0
            sage: p.add_variables(2)                               # optional - Coin
            1
            sage: p.ncols()                                       # optional - Coin
            2
        """

        return self.si.getNumCols()

    cpdef int nrows(self):
        r"""
        Returns the number of rows/constraints.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin") # optional - Coin
            sage: p.nrows()                                      # optional - Coin
            0
            sage: p.add_linear_constraints(2, 2, None)                     # optional - Coin
            sage: p.nrows()                                      # optional - Coin
            2
        """
        return self.si.getNumRows()


    cpdef bint is_variable_binary(self, int index):
        r"""
        Tests whether the given variable is of binary type.

        INPUT:

        - ``index`` (integer) -- the variable's id

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.ncols()                                       # optional - Coin
            0
            sage: p.add_variable()                                 # optional - Coin
            0
            sage: p.set_variable_type(0,0)                         # optional - Coin
            sage: p.is_variable_binary(0)                          # optional - Coin
            True

        """

        return (0 == self.si.isContinuous(index) and
                self.variable_lower_bound(index) == 0 and
                self.variable_upper_bound(index) == 1)

    cpdef bint is_variable_integer(self, int index):
        r"""
        Tests whether the given variable is of integer type.

        INPUT:

        - ``index`` (integer) -- the variable's id

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.ncols()                                       # optional - Coin
            0
            sage: p.add_variable()                                 # optional - Coin
            0
            sage: p.set_variable_type(0,1)                         # optional - Coin
            sage: p.is_variable_integer(0)                         # optional - Coin
            True
        """
        return (0 == self.si.isContinuous(index) and
                (self.variable_lower_bound(index) != 0 or
                self.variable_upper_bound(index) != 1))

    cpdef bint is_variable_continuous(self, int index):
        r"""
        Tests whether the given variable is of continuous/real type.

        INPUT:

        - ``index`` (integer) -- the variable's id

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.ncols()                                       # optional - Coin
            0
            sage: p.add_variable()                                 # optional - Coin
            0
            sage: p.is_variable_continuous(0)                      # optional - Coin
            True
            sage: p.set_variable_type(0,1)                         # optional - Coin
            sage: p.is_variable_continuous(0)                      # optional - Coin
            False

        """
        return 1 == self.si.isContinuous(index)


    cpdef bint is_maximization(self):
        r"""
        Tests whether the problem is a maximization

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin") # optional - Coin
            sage: p.is_maximization()                             # optional - Coin
            True
            sage: p.set_sense(-1)                             # optional - Coin
            sage: p.is_maximization()                             # optional - Coin
            False
        """

        return self.si.getObjSense() == -1

    cpdef variable_upper_bound(self, int index, value = False):
        r"""
        Returns or defines the upper bound on a variable

        INPUT:

        - ``index`` (integer) -- the variable's id

        - ``value`` -- real value, or ``None`` to mean that the
          variable has not upper bound. When set to ``False``
          (default), the method returns the current value.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.add_variable()                                 # optional - Coin
            0
            sage: p.col_bounds(0)                              # optional - Coin
            (0.0, None)
            sage: p.variable_upper_bound(0, 5)                         # optional - Coin
            sage: p.col_bounds(0)                              # optional - Coin
            (0.0, 5.0)
        """
        cdef double * ub

        if value == False:
            ub = <double*> self.si.getColUpper()
            return ub[index] if ub[index] != + self.si.getInfinity() else None
        else:
            self.si.setColUpper(index, value if value is not None else +self.si.getInfinity())

    cpdef variable_lower_bound(self, int index, value = False):
        r"""
        Returns or defines the lower bound on a variable

        INPUT:

        - ``index`` (integer) -- the variable's id

        - ``value`` -- real value, or ``None`` to mean that the
          variable has not lower bound. When set to ``False``
          (default), the method returns the current value.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.add_variable()                                 # optional - Coin
            0
            sage: p.col_bounds(0)                              # optional - Coin
            (0.0, None)
            sage: p.variable_lower_bound(0, 5)                         # optional - Coin
            sage: p.col_bounds(0)                              # optional - Coin
            (5.0, None)
        """
        cdef double * lb

        if value == False:
            lb = <double*> self.si.getColLower()
            return lb[index] if lb[index] != - self.si.getInfinity() else None
        else:
            self.si.setColLower(index, value if value is not None else -self.si.getInfinity())

    cpdef write_mps(self, char * filename, int modern):
        r"""
        Writes the problem to a .mps file

        INPUT:

        - ``filename`` (string)

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")  # optional - Coin
            sage: p.add_variables(2)                               # optional - Coin
            1
            sage: p.add_linear_constraint([(0, 1), (1, 2)], None, 3)          # optional - Coin
            sage: p.set_objective([2, 5])                          # optional - Coin
            sage: p.write_mps(SAGE_TMP+"/lp_problem.mps", 0)       # optional - Coin
        """

        cdef char * mps = "mps"
        self.si.writeMps(filename, mps, -1 if self.is_maximization() else 1)

    cpdef problem_name(self, char * name = NULL):
        r"""
        Returns or defines the problem's name

        INPUT:

        - ``name`` (``char *``) -- the problem's name. When set to
          ``NULL`` (default), the method returns the problem's name.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")   # optional - Coin
            sage: p.problem_name("There once was a french fry") # optional - Coin
            sage: print p.problem_name()                        # optional - Coin
            <BLANKLINE>
        """
        if name == NULL:
            return ""


    cpdef row_name(self, int index):
        r"""
        Returns the ``index`` th row name

        INPUT:

        - ``index`` (integer) -- the row's id

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")                                     # optional - Coin
            sage: p.add_linear_constraints(1, 2, None, names=['Empty constraint 1'])  # optional - Coin
            sage: print p.row_name(0)                                                 # optional - Coin
            <BLANKLINE>
        """
        return ""

    cpdef col_name(self, int index):
        r"""
        Returns the ``index`` th col name

        INPUT:

        - ``index`` (integer) -- the col's id

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = get_solver(solver = "Coin")          # optional - Coin
            sage: p.add_variable(name='I am a variable')   # optional - Coin
            0
            sage: print p.col_name(0)                      # optional - Coin
            <BLANKLINE>
        """
        return ""

    cpdef CoinBackend copy(self):
        """
        Returns a copy of self.

        EXAMPLE::

            sage: from sage.numerical.backends.generic_backend import get_solver
            sage: p = MixedIntegerLinearProgram(solver = "Coin")        # optional - Coin
            sage: b = p.new_variable()                         # optional - Coin
            sage: p.add_constraint(b[1] + b[2] <= 6)           # optional - Coin
            sage: p.set_objective(b[1] + b[2])                 # optional - Coin
            sage: copy(p).solve()                              # optional - Coin
            6.0

        """
        cdef CoinBackend p = CoinBackend(maximization = (1 if self.is_maximization() else -1))

        p.si = new2_c_OsiCbcSolverInterface(<OsiSolverInterface *> self.si)

        return p
