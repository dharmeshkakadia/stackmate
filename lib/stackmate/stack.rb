require 'json'
require 'set'
require 'tsort'
require 'stackmate/logging'

module StackMate

class Stacker
    include TSort
    include Logging

    def initialize(templatefile, stackname, params)
        @stackname = stackname
        @resolved = {}
        stackstr = File.read(templatefile)
        @templ = JSON.parse(stackstr) 
        @templ['StackName'] = @stackname
        @param_names = @templ['Parameters']
        @deps = {}
        @pdeps = {}
        resolve_param_refs(params)
        validate_param_values
        resolve_dependencies()
        @templ['ResolvedNames'] = @resolved
    end

    def resolve_param_refs(params)
        params.split(';').each do |p|
           i = p.split('=')
           @resolved[i[0]] = i[1]
        end
        @resolved['AWS::Region'] = 'us-east-1' #TODO handle this better
    end
    
    def validate_param_values
        #TODO CloudFormation parameters have validity constraints specified
        #Use them to validate parameter values (e.g., email addresses)
    end

    def resolve_dependencies
        @templ['Resources'].each { |key,val| 
            deps = Set.new
            pdeps = Set.new
            find_refs(key, val, deps, pdeps)
            deps << val['DependsOn'] if val['DependsOn']
            #print key, " depends on ", deps.to_a, "\n"
            @deps[key] = deps.to_a
            @pdeps[key] = pdeps.to_a
        }
        @pdeps.keys.each do |k|
            unres = @pdeps[k] - @resolved.keys
            if ! unres.empty?
                unres.each do |u|
                    deflt = @param_names[u]['Default']
                    #print "Found default value ", deflt, " for ", u, "\n" if deflt
                    @resolved[u] = deflt if deflt
                end
                unres = @pdeps[k] - @resolved.keys
                throw :unresolved, (@pdeps[k] - @resolved.keys) if !unres.empty?
            end
        end
    end


    def find_refs (parent, jsn, deps, pdeps)
        case jsn
            when Array
                jsn.each {|x| find_refs(parent, x, deps, pdeps)}
                #print parent, ": ", jsn, "\n"
            when Hash
                jsn.keys.each do |k|
                    #TODO Fn::GetAtt
                    if k == "Ref"
                        #only resolve dependencies on other resources for now
                        if !@param_names.keys.index(jsn[k]) && jsn[k] != 'AWS::Region' && jsn[k] != 'AWS::StackId'
                            deps << jsn[k]
                            #print parent, ": ", deps.to_a, "\n"
                        else if @param_names.keys.index(jsn[k])
                            pdeps << jsn[k]
                        end
                        end
                    else
                        find_refs(parent, jsn[k], deps, pdeps)
                    end
                end
        end
        return deps
    end

    def tsort_each_node(&block)
        @deps.each_key(&block)
    end

    def tsort_each_child(name, &block)
        @deps[name].each(&block) if @deps.has_key?(name)
    end
    
end

end
