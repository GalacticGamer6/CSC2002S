JAVAC = javac
JAVA = java

JFLAGS = --release 11 -d bin

SOURCES = FirelineParallel.java FireMapParallel.java FireTask.java FireMap.java TerrainType.java

ARGS ?= 500 500 17 wildfire output/run17 50000 0.05 mixed

.PHONY: all run

all:
	$(JAVAC) $(JFLAGS) $(SOURCES)

run: all
	$(JAVA) -cp bin FirelineParallel $(ARGS)
	