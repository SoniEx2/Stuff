Mental Garbage Collector
========================

Rationale
---------

Garbage collection is a complicated thing. Here we explore a different kind of GC,
which as far as I know is not used by anything. It aims to solve no problem other
than to use more RAM than conventional GCs. Because more RAM usage = better GC.

How conventional garbage collection works
-------------------------

Usually garbage collection works based on reference counting, and then a cyclic GC
collects cyclic references.

How my garbage collection works
---------------

Unlike conventional garbage collection, my garbage collector aims to do both at the
same time in a really silly way. I had the idea when trying to solve a problem with
Minecraft chunk (un)loading.

The GC works in 3 steps:
1. Prepare objects for GC cycle.
2. Scan objects from an entry point.
3. Collect garbage.

### Step 1: Preparing objects

For my GC to work, all objects need a "reference" counter, and the host needs a list
of objects. You basically iterate thru the list setting every counter back to 0.

### Step 2: Scan objects from an entry point

You start from your global namespace, and for every object you find, you put it in a
hash table to avoid infinite recursion (this is where the RAM usage comes from), and
also increment its counter by 1.

### Step 3: Collect garbage

After step 2 is done you want to iterate your object list and destroy all the objects
which have their counter still set to 0. This is your garbage collection cycle done!

Conclusion
----------

Don't do this. It's bad. It's silly. You don't even need an integer, or a hash table
for that matter, a boolean would do just fine.
