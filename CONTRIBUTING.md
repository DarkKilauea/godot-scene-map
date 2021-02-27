# Guidelines for contributing

Thanks for your interest in contributing! Before contributing, be sure to know
about these few guidelines:

- Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_styleguide.html).
  - Comment all public methods (methods intended for users to call) with a JSDoc like syntax.
- Use [GDScript static typing](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/static_typing.html) whenever possible.
  - Also use type inference whenever possible (`:=`) for more concise code.
- Don't bump the version yourself. Maintainers will do this when necessary.
- Try to keep your PRs as specific as possible.  The larger the PR, the more time it will take to approve (and the greater chance it may be rejected).

## Design goals

This add-on aims to:

- Provide an alternative to GridMap based on scenes, not meshes.
- Help artists quickly build worlds using 3D "tiles".

## Non-goals

For technical or simplicity reasons, this add-on has no plans to:

- Provide the same performance benefits of GridMap (for example: merging meshes together into octants).
- Prevent users from losing changes if they modify scenes "managed" by SceneMap and then modify those cells with the SceneMap tool.
