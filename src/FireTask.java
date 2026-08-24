//this is a task that we will have each thread run  in Firemap,
// All it does is split the region into smaller and smaller pieces and use the update region method from the serial FireMap
import java.util.concurrent.RecursiveTask;

public class FireTask extends RecursiveTask<FireMap.StepResult> {
    private final FireMap map;
    private final FireMap.Mode mode;
    private final int rowStart,rowEnd,columnStart,columnEnd,sequentialCutoff;

    //takes in the map, mode, row start/end, colstart/end (for the region to be processed), and the sequential cutoff
    public FireTask(FireMap map,FireMap.Mode mode,int rowStart,
                    int rowEnd,int columnStart,int columnEnd,int sequentialCutoff) 
    {
        this.map = map;
        this.mode = mode;
        this.rowStart = rowStart;
        this.rowEnd = rowEnd;
        this.columnStart = columnStart;
        this.columnEnd = columnEnd;
        this.sequentialCutoff = sequentialCutoff;
    }

    //compute method
    @Override
    protected FireMap.StepResult compute() {
        int rowCount = rowEnd - rowStart;
        int columnCount = columnEnd - columnStart;
        //tried usign int but for some reason didnt work, then i ragequit so chatbot said use long. dont even ask
        long numberOfCells = (long) rowCount * columnCount;

        // basic aaah thing that goes in every slide in the notes
        if (numberOfCells <= sequentialCutoff) {
            return map.updateRegion(mode,rowStart,rowEnd,columnStart,columnEnd);
        }

        FireTask LeftTask;
        FireTask RightTask;

        // split along the longer side so we havee more balanced regions
        if (rowCount >= columnCount) {
            int middleRow = rowStart + rowCount / 2;
            // look suspiciously similar to class test 1 icl cough cough
            LeftTask = new FireTask(map,mode,rowStart,middleRow,columnStart,
                    columnEnd,sequentialCutoff);
            RightTask = new FireTask(map,mode,middleRow,rowEnd,columnStart,
                    columnEnd,sequentialCutoff);

        } else {
            int middleColumn = columnStart + columnCount / 2;
            LeftTask = new FireTask(map,mode,rowStart,rowEnd,columnStart,
                    middleColumn,sequentialCutoff);
            RightTask = new FireTask(map,mode,rowStart,rowEnd,middleColumn,
                    columnEnd,sequentialCutoff);
        }
        //same as every attendanc quiz
        LeftTask.fork();
        FireMap.StepResult secondResult = RightTask.compute();
        FireMap.StepResult firstResult = LeftTask.join();
        
        return FireMap.StepResult.combine(firstResult, secondResult);
    }
}
