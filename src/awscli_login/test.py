from daemoniker import Daemonizer
with Daemonizer() as (is_setup, daemonizer):
    if is_setup:
        # This code is run before daemonization.
        print("Setup")
        
        # We need to explicitly pass resources to the daemon; other variables
        # may not be correct
        is_parent = daemonizer(
            "my.pid.file",
        )
    
    if is_parent:
        # Run code in the parent after daemonization
        print("Parent")
    else:
        print("Child")
