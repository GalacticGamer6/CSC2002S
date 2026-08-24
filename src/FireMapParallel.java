import java.util.concurrent.ForkJoinPool;

// same as the serial , but all we do is add a parlall version of the steo function
public class FireMapParallel extends FireMap {
    private final int rows,columns,sequentialCutoff;
    private final ForkJoinPool pool;

    //create the constructor , just taking in account the cutoff
    public FireMapParallel(int rows,int columns,long seed,Mode mode,
                           Landscape landscape,Integer ignitionTopRow,
                           Integer ignitionLeftColumn,Integer ignitionPatchSize,
                           int sequentialCutoff)
    {
        super(rows,columns,seed,mode,landscape,ignitionTopRow,
                ignitionLeftColumn,ignitionPatchSize);

        if (sequentialCutoff <= 0) {
            throw new IllegalArgumentException(
                    "Sequential cutoff must be positive.");
        }

        this.rows = rows;
        this.columns = columns;
        this.sequentialCutoff = sequentialCutoff;
        this.pool = ForkJoinPool.commonPool();
    }

    public StepResult stepParallel(Mode mode) {

        // Prepare the next buffers so that neighboring cells can be read from the current buffer and written to the next buffer.
        prepareNextState();
        FireTask Task = new FireTask(this,mode,1,rows - 1,1,columns - 1,sequentialCutoff);
        pool.execute(Task);
        StepResult result = Task.join();
        //same as serial, call after all grid regions have been updated to swap the current and next buffers and update the step count.
        completeStep();
        return result;
    }
}
