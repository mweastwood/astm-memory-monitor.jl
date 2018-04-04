module Monitor

const machines = [@sprintf("astm%02d", astm) for astm=4:13]

struct MemoryUsage
    time :: UInt64
    mem_total :: Dict{String, Int}
    mem_used  :: Dict{String, Int}
    swp_total :: Dict{String, Int}
    swp_used  :: Dict{String, Int}
end

function free()
    result = readstring(`pdsh -w astm\[04-13\] free`)
    lines  = split(result, "\n")
    line_words = [split(line) for line in lines]
    mem_total = Dict{String, Int}()
    mem_used  = Dict{String, Int}()
    swp_total = Dict{String, Int}()
    swp_used  = Dict{String, Int}()
    for words in line_words
        length(words) > 0 || continue
        machine   = strip(words[1], ':')
        if words[2] == "Mem:"
            mem_total[machine] = parse(Int, words[3])
        elseif words[2] == "-/+"
            mem_used[machine] = parse(Int, words[4])
        elseif words[2] == "Swap:"
            swp_total[machine] = parse(Int, words[3])
            swp_used[machine] = parse(Int, words[4])
        end
    end
    MemoryUsage(time_ns(), mem_total, mem_used, swp_total, swp_used)
end

mutable struct Tracker
    current :: MemoryUsage
end

function Tracker()
    Tracker(free())
end

function display(tracker)
    @printf("┌────────┬──────")
    for machine in machines
        @printf("┬─────────")
    end
    @printf("┐\n")

    @printf("│        │   MB │")
    for machine in machines
        @printf(" %7s │", machine)
    end
    @printf("\n")

    #@printf("│      │")
    #for machine in machines
    #    @printf(" %7s │", "pckt/s")
    #end
    #@printf("\n")

    for (name, used, total) in (("Memory", tracker.current.mem_used, tracker.current.mem_total),
                                ("Swap",   tracker.current.swp_used, tracker.current.swp_total))
        @printf("├────────┼──────")
        for machine in machines
            @printf("┼─────────")
        end
        @printf("┤\n")

        # FIRST LINE
        @printf("│ %6s │ Used │", name)
        for machine in machines
            @printf("  %6d │", used[machine]/1024)
        end
        @printf("\n")

        # SECOND LINE
        @printf("│ %6s │ Free │", "")
        for machine in machines
            @printf("  %6d │", (total[machine]-used[machine])/1024)
        end
        @printf("\n")
    end

    @printf("└────────┴──────")
    for machine in machines
        @printf("┴─────────")
    end
    @printf("┘\n")
end

function return_to_top(tracker::Tracker)
    for idx = 1:9
        print("\033[F") # go back to the top
    end
end

function track()
    tracker = Tracker()
    display(tracker)
    while true
        sleep(3)
        tracker.current = free()
        return_to_top(tracker)
        display(tracker)
    end
end

function main()
    try
        track()
    catch exception
        if exception isa InterruptException
            quit()
        else
            rethrow(exception)
        end
    end
end

end

