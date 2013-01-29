"""
A wrapper around greenlet that provides support for things like sleeping and
yielding.

This "green threading" system is useful for dealing with APIs that aren't
thread-safe.
"""

from __future__ import division
import time
import greenlet

class Fiber(greenlet.greenlet):
    def __init__(self, runnable=None, priority=10):
        self.__state = None
        self.priority = priority
        if runnable:
            self.runnable = runnable
        self.__start_time = None
        self.__execution_time = None
    
    def step(self):
        """
        Will raise a :class:`StopIteration` exception when we're done.
        """
        if self.__state is None:
            self.__state = self.runnable()
            self.__start_time = time.time()
        run_start_time = time.time()
        
        next(self.__state)
        
        if self.__execution_time is None: self.__execution_time = 0
        self.__execution_time += max(run_start_time - run_start_time, 1e-6)
    
    def get_age(self):
        return time.time() - self.__start_time
    
    age = property(get_age)
    
    def get_execution_time(self):
        return self.__execution_time
    
    execution_time = property(get_execution_time)
    
    def get_execution_score(self):
        """
        The higher an execution score, the sooner it will be run. If this has
        never been run before, ``float("inf")`` is returned.
        """
        if self.execution_time is None:
            return float("inf")
        return self.age / self.execution_time * self.priority
    
    execution_score = property(get_execution_score)
    
    def runnable(self):
        """
        Should ``yield`` after small increments of work. If done, it should
        ``return``. If no more work can possibly be done given the current
        dataset, but more can potentially be done later, it should
        ``yield False``. If it should sleep, it should return a number.
        """
        pass

class FiberManager:
    def __init__(self, processes):
        self.__processes = set(processes)
        self.__invalidated_processes = set()
    
    def get_processes(self):
        return iter(self.__processes)
    
    processes = property(get_processes)
    
    def run(self, minimum_time=float("inf")):
        """
        Run processes until at least ``minimum_time`` has passed, where
        ``minimum_time`` is a floating-point time in seconds, unless there are
        no tasks to do.
        """
        start_time = time.time()
        while time.time() - start_time < minimum_time and \
                      len(self.__processes) - len(self.__invalidated_processes):
            target_task = max(self.__processes - self.__invalidated_processes,
                              key=lambda x: x.execution_score)
            try:
                if target_task.step() is False:
                    self.__invalidated_processes.add()
                else:
                    self.__invalidated_processes.clear()
            except StopIteration:
                remove_process(self, process)
    
    def add_process(self, process):
        """
        Add a process to the process list. Fiberes can be added during
        execution.
        """
        self.__processes.append(process)
        self.__invalidated_processes.clear()
    
    def remove_process(self, process):
        self.__processes.remove(process)
        if process in self.__invalidated_processes:
            self.__invalidated_processes.remove(target_task)

# Create one module-level default instance, like the stdlib's random module does
_inst = FiberManager()

if __name__ == "__main__":
    class RangePrinterFiber(Fiber):
        def runnable(self):
            for i in range(20):
                print(i)
                yield False
    processes = [RangePrinterFiber() for i in range(3)]
    FiberManager(processes).run()
