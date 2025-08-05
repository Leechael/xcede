import lldb
import time
import os

def printnow(s):
    print(s, flush=True)

def __lldb_init_module(debugger, internal_dict):
    paramsFile = ".xcede/attach-params"
    with open(paramsFile, "r") as file:
        params = file.read().splitlines()
        device_id = params[0]
        process_name = params[1]
        printnow(f"Attach to {process_name} on {device_id}")

        # This can help if having trouble; otherwise it's pretty noisy:
        # debugger.HandleCommand("log enable lldb process")
        debugger.HandleCommand("platform select remote-ios")

        for attempt in range(10):
            printnow("Waiting for device...")
            try:
                result = lldb.SBCommandReturnObject()
                debugger.GetCommandInterpreter().HandleCommand("device list", result)
                output = result.GetOutput()

                # This should be more robust. Be more specific about name, and look for "connected" too.
                if device_id in output:
                    break

            except Exception as e:
                print(f"Attempt {attempt + 1}: Exception occurred: {e}")

            time.sleep(1)
        else:
            print(f"Device {device_id} not found; giving up")
            return

        printnow("Connecting to device...")
        debugger.HandleCommand(f"device select {device_id}")

        printnow("Attaching to app process...")
        debugger.HandleCommand(f"device process attach --name {process_name} --include-existing --waitfor")
        # We need to wait for process status to stabilise to "stopped"
        for _ in range(20):
            result = lldb.SBCommandReturnObject()
            debugger.GetCommandInterpreter().HandleCommand("process status", result)
            output = result.GetOutput()
            if "stopped" in output or "state = stopped" in output:
                # debugger.HandleCommand("continue")
                print("Ready!")
                return
            time.sleep(1)

        print("Giving up: attach did not complete in time.")

    os.remove(paramsFile)
