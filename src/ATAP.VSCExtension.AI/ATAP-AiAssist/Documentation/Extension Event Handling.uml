@startuml
participant "main" as Main
participant "VisualState" as VState
participant "Event" as Event
participant "EventListener" as Listener
participant "EventGuard" as Guard

Main -> VState : new VisualState()
Main -> Event : new Event()
Main -> Listener : new EventListener()
Main -> Guard : new EventGuard(Listener)
Main -> Event : register(Listener)
Main -> Guard : setListenerReady(true)

Main -> VState : changeState("initializing")
note right of VState : Visual state now 'initializing'

alt is Listener Ready?
  Main -> VState : changeState("event_pending")
  note right of VState : Visual state changes when event is pending
  Guard -> Event : canFireEvent()
  Event -> VState : changeState("event_fired")
  note right of VState : Visual state changes when event fires
  Event -> Listener : handleEvent()
  Listener -> VState : changeState("listener_processing")
  note right of VState : Visual state changes to 'listener_processing'
  Listener -> VState : changeState("listener_done")
  note right of VState : Visual state changes back after listener is done
else
  Main -> Event : waitForListener()
  note right of Event : Event waits until listener\nis marked as ready
end

@enduml
