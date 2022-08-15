# Concord

Concord is a feature complete ECS for LÖVE.
It's main focus is performance and ease of use.
With Concord it is possibile to easily write fast and clean code.

This readme will explain how to use Concord.

Additionally all of Concord is documented using the LDoc format.
Auto generated docs for Concord can be found in `docs` folder, or on the [GitHub page](https://flyingsl0ths.github.io/Concord/).

---

## Table of Contents

[Installation](#installation)  
[ECS](#ecs)  
[API](#api) :

- [Components](#components)
- [Entities](#entities)
- [Systems](#systems)
- [Worlds](#worlds)
- [Assemblages](#assemblages)

[Quick Example](#quick-example)  
[Contributors](#contributors)  
[License](#licence)

---

## Installation

Download the repository and copy the 'Concord' folder into your project. Then require it in your project like so:

```lua
local Concord = require("path.to.concord")
```

Concord has a bunch of modules. These can be accessed through `Concord`:

```lua
-- Modules
local Entity = Concord.entity
local Component = Concord.component
local System = Concord.system
local World = Concord.world

-- Containers
local Components = Concord.components
```

---

## ECS

Concord is an Entity Component System (ECS for short) library.
This is a coding paradigm where _composition_ is used over _inheritance_.
Because of this it is easier to write more modular code. It often allows you to combine any form of behaviour for the objects in your game (Entities).

As the name might suggest, ECS consists of 3 core things: Entities, Components, and Systems. A proper understanding of these is required to use Concord effectively.
We'll start with the simplest one.

### Components

Components are pure raw data. In Concord this is just a table with some fields.
A position component might look like
`{ x = 100, y = 50}`, whereas a health Component might look like `{ currentHealth = 10, maxHealth = 100 }`.
What is most important is that Components are data and nothing more. They have 0 functionality.

### Entities

Entities are the actual objects in your game. Like a player, an enemy, a crate, or a bullet.
Every Entity has it's own set of Components, with their own values.

A crate might have the following components (Note: Not actual Concord syntax):

```lua
{
    position = {x = 100, y = 200},
    texture = {path = "crate.png", image = Image},
    pushable = {}
}
```

Whereas a player might have the following components:

```lua
{
    position = {x = 200, y = 300},
    texture = {path = "player.png", image = Image},
    controllable = {keys = "wasd"},
    health = {currentHealth = 10, maxHealth = 100}
}
```

Any Component can be given to any Entity (once). Which Components an Entity has will determine how it behaves. This is done through the last thing...

### Systems

Systems are the things that actually _do_ stuff. They contain all your fancy algorithms and cool game logic.
Each System will do one specific task like say, drawing Entities.
For this they will only act on Entities that have the Components needed for this: `position` and `texture`. All other Components are irrelevant.

In Concord this is done something alike this:

```lua
-- Defines a System with an id, name, and that takes all Entities with a position and texture Component
drawSystem = System(system_id, system_name, {position, texture})

function drawSystem:draw() -- Give it a draw function
    -- Iterate over all Entities that this System acts on
    for _, entity in ipairs(self.pool) do
        -- Get the position Component of this Entity
        local position = entity:f_get(position_component_id)
        -- Get the texture Component of this Entity
        local texture = entity:f_get(texture_component_id)

        -- Draw the Entity
        love.graphics.draw(texture.image, position.x, position.y)
    end
end
```

### To summarize...

- Components contain only data.
- Entities contain any set of Components.
- Systems act on Entities that have a required set of Components.

By creating Components and Systems you create modular behaviour that can apply to any Entity.
What if we took our crate from before and gave it the `controllable` Component? It would respond to our user input of course.

Or what if the enemy shot bullets with a `health` Component? It would create bullets that we'd be able to destroy by shooting them.

And all that without writing a single extra line of code. Just reusing code that already existed and is guaranteed to be reuseable.

---

## API

### General design

Concord does a few things that might not be immediately clear. This segment should help understanding.

#### Requiring files

Since you'll have lots of Components and Systems in your game Concord makes it a bit easier to load things in.

`Utils.loadNamespace` loads all files in the directory, and puts the return value in the table `Systems`.
The key is their filename without any extension

```lua
local Systems = {}
Concord.utils.loadNamespace("path/to/systems", Systems)

print(Systems.filename)
```

Components are automatically registered into `Concord.components`, so loading them into
a namespace isn't necessary.

#### Method chaining

Most (if not all) methods will return `self` This allows you to chain methods

```lua
my_entity:give(position_id, 100, 100):give(velocity_id, 100, 0)
    :give(drawable_id):give(player_input_id):remove(position_id):destroy()

my_world:addEntity(foo_entity):addEntity(bar_entity):clear():emit("test")
```

### Components

When defining a `ComponentClass` you need to pass in an id, a name, and usually a
`populate` function. This will fill the Component with values.

```lua
-- Create the position class with a populate function
-- The component variable is the actual Component given to an Entity
-- The x and y variables are values we pass in when we create the Component
Concord.component(id, "position", function(component, x, y)
    component.x = x or 0
    component.y = y or 0
end)

-- Create a ComponentClass without a populate function
-- Components of this type won't have any fields.
-- This can be useful as an tag
Concord.component(id, "draw")
```

### Entities

Entities can be freely made and be given Components. You pass the name of the `ComponentClass` and the values you want to pass. It will then create the Component for you.

Entities will contain a **single** instance of a `Component` and can not share that instance

```lua
-- Create a new Entity
local my_entity = Entity()
-- or
local my_entity = Entity(my_world) -- Adds it to a world immediately ( See World )
```

```lua
-- Give the entity the position Component defined above
-- x will become 100. y will become 50
my_entity:give(position_component_id, 100, 50)
```

```lua
-- Retrieve a Component
-- Entity:get can also be used as well, which is the "safe" version of Entity:f_get
-- Entity:f_get is preferred when you know for a fact that the Entity will have
-- the requested component
local position = my_entity:f_get(position_component_id)

print(position.x, position.y) -- 100, 50
```

```lua
-- Removing a Component
myEntity:remove(component_id)
```

```lua
-- Entity:give will override a Component if the Entity already has it
-- Entity:ensure will only put the Component if the Entity does not already have it

Entity:ensure(position_component_id, 0, 0) -- Will give
-- Position is {x = 0, y = 0}

Entity:give(position_component_id, 50, 50) -- Will override
-- Position is {x = 50, y = 50}

Entity:give(position_component_id, 100, 100) -- Will override
-- Position is {x = 100, y = 100}

Entity:ensure(position_component_id, 0, 0) -- Wont do anything
-- Position is {x = 100, y = 100}
```

```lua
-- Retrieve all Components
-- WARNING: Do not modify this table. It is read-only
local all_components = my_entity:getComponents()

for _, component in ipairs(all_components) do
    -- Do stuff
end
```

```lua
-- Assemble the Entity ( See Assemblages )
my_entity:assemble(assemblage_function, 100, true, "foo")
```

```lua
-- Check if the Entity is in a world
local in_world = my_entity:inWorld()

-- Get the World the Entity is in
local world = my_entity:getWorld()
```

```lua
-- Destroy the Entity
my_entity:destroy()
```

### Systems

`Systems` are defined as a `SystemClass`. Concord will automatically create an instance of a `System` when it is needed.

Systems get access to Entities through a `pool` and are created using a filter.
Systems can only have a **single** pool.

```lua
-- Creates a System with the entities that contain
-- the given components as stated by the filter
local my_system_class = Concord.system(id, name, {component_ids})
```

```lua
-- If a System has an :init function it will be called on creation

-- world is the World the System was created for
function my_system_class:init(world)
    -- Do stuff
end
```

```lua
-- Defining a callback (see World)
function my_system_class:update(dt)
    -- Iterate over all entities in the pool
    for _, entity in ipairs(self.pool)
        -- Do something with the Components
    end
end
```

```lua
-- Systems can be enabled and disabled
-- When systems are disabled their callbacks won't be executed.
-- Note that pools will still be updated
-- Systems are enabled by default

-- Enable a System
my_system:setEnable(true)

-- Disable a System
my_system:setEnable(false)

-- Get enabled state
local is_enabled = my_system:isEnabled()
print(is_enabled) -- false
```

```lua
-- Get the World the System is in
local world = system:getWorld()
```

### Worlds

Worlds are the thing your Systems and Entities live in.
With Worlds you can `emit` a callback. All Systems with this callback will then be called.

Worlds can have 1 instance of every `SystemClass`.
Worlds can have any number of Entities.

```lua
-- Create World
local my_world = Concord.world()
```

```lua
-- Add an Entity to the World
my_world:addEntity(my_entity)

-- Remove an Entity from the World
my_world:removeEntity(my_entity)
```

```lua
-- Add a System to the World
myWorld:addSystem(my_system_class)

-- Add multiple Systems to the World
myWorld:addSystems(move_system_class, render_system_class, control_system_class)
```

```lua
-- Check if the World has a System
local has_system = myWorld:hasSystem(my_system_class)

-- Get a System from the World
local my_system = myWorld:getSystem(my_system_class)
```

```lua
-- Emit an event

-- This will call the 'update' function of all added Systems if they have one
-- They will be called in the order they were added
my_world:emit("update", dt)

-- You can emit any event with any parameters
my_world:emit("customCallback", 100, true, "Hello World")
```

```lua
-- Remove all Entities from the World
my_world:clear()
```

```lua
-- Override-able callbacks

-- Called when an Entity is added to the World
-- e is the Entity added
function my_world:onEntityAdded(e)
    -- Do something
end

-- Called when an Entity is removed from the World
-- e is the Entity removed
function my_world:onEntityRemoved(e)
    -- Do something
end
```

### Assemblages

Assemblages are functions to "make" Entities into something.
An important distinction is that they _append_ Components.

```lua
-- Make an Assemblage function
-- e is the Entity being assembled.
-- cuteness and legs are variables passed in
function animal(e, cuteness, legs)
    e:give(cuteness_component_id, cuteness):give(limbs_component_id, legs, 0) -- Variable amount of legs. 0 arm.
end

-- Assumble an Entity using the animal assemblage
-- cuteness is a variable passed in
function cat(e, cuteness)
    e:assemble(animal, cuteness * 2, 4) -- Cats are twice as cute, and have 4 legs.
    :give(sound_component_id, "meow.mp3")
end
```

```lua
-- Using an assemblage
my_entity:assemble(cat, 100) -- 100 cuteness
```

---

## Quick Example

```lua
local Concord = require("concord")

local ComponentIds = Concord.utils.readOnly({
    POSITION = 1,
    VELOCITY = 2,
    DRAWABLE = 3,
    PLAYER_INPUT = 4
})

local SystemIds = Concord.utils.readOnly({MOVE = 1, DRAW = 2, PLAYER_INPUT = 3})

Concord.component(ComponentIds.POSITION, "position", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

Concord.component(ComponentIds.VELOCITY, "velocity", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

Concord.component(ComponentIds.DRAWABLE, "drawable")

Concord.component(ComponentIds.PLAYER_INPUT, "input")

local PlayerInputSystem = Concord.system(SystemIds.PLAYER_INPUT, "player_input",
                                         {
    ComponentIds.VELOCITY, ComponentIds.PLAYER_INPUT
})

function PlayerInputSystem:update()
    local e = self.pool[1]
    local velocity_component = e:f_get(ComponentIds.VELOCITY)

    if love.keyboard.isDown("left") then
        if velocity_component.x >= 0 then
            velocity_component.x = -velocity_component.x
        end
    end

    if love.keyboard.isDown("right") then
        if velocity_component.x < 0 then
            velocity_component.x = velocity_component.x * -1
        end
    end

    if love.keyboard.isDown("up") then
        if velocity_component.y < 0 then
            velocity_component.y = velocity_component.y * -1
        end
    end

    if love.keyboard.isDown("down") then
        if velocity_component.y >= 0 then
            velocity_component.y = -velocity_component.y
        end
    end
end

local MoveSystem = Concord.system(SystemIds.MOVE, "move", {
    ComponentIds.POSITION, ComponentIds.VELOCITY
})

function MoveSystem:update(dt)
    local function onMove(entity)
        local position_component = entity:f_get(ComponentIds.POSITION)
        local velocity_component = entity:f_get(ComponentIds.VELOCITY)

        local vx = velocity_component.x
        local vy = velocity_component.y

        position_component.x = position_component.x + vx * dt
        position_component.y = position_component.y + vy * dt
    end

    for _, entity in ipairs(self.pool) do onMove(entity) end
end

local DrawSystem = Concord.system(SystemIds.DRAW, "draw", {
    ComponentIds.POSITION, ComponentIds.DRAWABLE
})

function DrawSystem:draw()
    for _, entity in ipairs(self.pool) do
        local position_component = entity:f_get(ComponentIds.POSITION)

        love.graphics.circle("fill", position_component.x, position_component.y,
                             20)
    end
end

local world = Concord.world()

world:addSystems(MoveSystem, PlayerInputSystem, DrawSystem)

Concord.entity(world):give(ComponentIds.POSITION, 100, 100):give(
    ComponentIds.VELOCITY, 100, 0):give(ComponentIds.DRAWABLE):give(
    ComponentIds.PLAYER_INPUT)

Concord.entity(world):give(ComponentIds.POSITION, 120, 120):give(
    ComponentIds.VELOCITY, 110, 0):give(ComponentIds.DRAWABLE)

function love.update(dt) world:emit("update", dt) end

function love.draw() world:emit("draw") end

```

---

## Contributors

See https://github.com/Keyslam/Concord#contributors for the original list of contributors

---

## License

MIT Licensed - Copyright Justin van der Leij (Tjakka5)
