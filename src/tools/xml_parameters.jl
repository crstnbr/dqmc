using LightXML

"""
    xml2parameters!(p::Params, input_xml)
    
Load `p` from XML file (e.g. `.in.xml`).
"""
function xml2parameters!(p, input_xml::AbstractString, verbose=true)
  # READ INPUT XML
  params = Dict{Any, Any}()
  try
    params = xml2dict(input_xml, verbose)

  catch e
    println(e)
  end

  set_parameters(p, params)

  params
end

function xml2dict(fname::AbstractString, verbose::Bool=true)
  params = Dict{Any, Any}()
  xdoc = parse_file(fname)
  xroot = LightXML.root(xdoc)
  for c in child_nodes(xroot)
    if is_elementnode(c)
      for p in child_nodes(c)
        if is_elementnode(p)
          e = XMLElement(p)
          if LightXML.name(e) == "PARAMETER"
            verbose && println(attribute(e, "name"), " = ", content(e))
            params[attribute(e, "name")] = content(e)
          end
        end
      end
    end
  end
  return params
end

function paramset2xml(params::Dict, prefix::AbstractString)
  for (i, param_set) in enumerate(product(values(params)...))
    xdoc = XMLDocument()
    xroot = create_root(xdoc, "SIMULATION")
    pn = new_child(xroot, "PARAMETERS")
    for (k, p) in zip(keys(params), param_set)
      pc = new_child(pn, "PARAMETER")
      add_text(pc, string(p))
      set_attribute(pc, "name", string(k))
    end
    save_file(xdoc, prefix * ".task" * string(i) * ".in.xml")
  end
end

function params2xml(params::Dict, prefix::AbstractString, taskid::Int; overwrite=false, ext=".in.xml", root="")
  xdoc = XMLDocument()
  xroot = create_root(xdoc, "SIMULATION")
  pn = new_child(xroot, "PARAMETERS")
  for (k, p) in params
    pc = new_child(pn, "PARAMETER")
    add_text(pc, string(p))
    set_attribute(pc, "name", string(k))
  end
  of = joinpath(root, prefix * ".task" * string(taskid) * ext)
  (!isfile(of) || overwrite) && save_file(xdoc, of)
end