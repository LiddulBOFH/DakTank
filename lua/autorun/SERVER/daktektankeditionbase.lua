if SERVER then
	hook.Add( "InitPostEntity", "DakTekTankEditionRunOnLoadHook", function()
		local Settings = physenv.GetPerformanceSettings() // copy table from physenfv
		Settings.MaxVelocity = 1000000 // change max velocity
		physenv.SetPerformanceSettings(Settings) // push max velocity back into engine.
		print("DakTekTankEditionLoaded")
	end)


	DakTankShellList = {} --Create Entity list for storing things people spawn
	DakTankLastShellThink = 0
	--Setup global daktek function for setting up affected entities.
	function DakTekTankEditionSetupNewEnt(ent)
		if IsValid(ent) and not (string.Explode("_",ent:GetClass(),false)[1] == "dak") then --make sure its not daktek stuff
	 		--setup values
	 		if ent.IsDakTekFutureTech == nil then
	 			ent.DakBurnStacks = 0
				ent.DakName = "Armor"
				if ent.EntityMods and ent.EntityMods.IsERA==1 then 
					ent.DakMaxHealth = 5
					ent.DakPooled = 1
				else
					if ent:GetClass() == "prop_ragdoll" then
		 				ent.DakHealth = 100000000000000000000
		 			else
			 			if IsValid(ent:GetPhysicsObject()) then
					 		ent.DakHealth = ent:GetPhysicsObject():GetMass()/20
					 	else
					 		ent.DakHealth = 100000000000000000000
					 	end
					end
					if IsValid(ent:GetPhysicsObject()) then
				 		ent.DakMaxHealth = ent:GetPhysicsObject():GetMass()/20
			 		else
				 		ent.DakMaxHealth = 100000000000000000000
				 	end
			 		ent.DakPooled = 0
			 	end
		 		--1 mm of armor on a meter*meter plate would be 8kg
		 		--1 kg gives 0.125 armor
		 		if ent:IsSolid() then
		 			if IsValid(ent:GetPhysicsObject()) then
		 				local SA = ent:GetPhysicsObject():GetSurfaceArea()
		 				if SA == nil then
		 					--Volume = (4/3)*math.pi*math.pow( ent:OBBMaxs().x, 3 )
		 					ent.DakArmor = ent:OBBMaxs().x/2
		 					ent.DakIsTread = 1
		 				else
		 					ent.DakArmor = 7.8125*(ent:GetPhysicsObject():GetMass()/4.6311781)*(288/SA) - ent.DakBurnStacks*0.25
		 				end
				 	end
			 	else
			 		ent.DakArmor = 0
			 	end
			else
				ent.DakArmor = 1000
			end
	 		--ent.DakArmor = (ent:GetPhysicsObject():GetMass()*0.125)
		else
			if IsValid(ent) then
				--exceptions for bots
				if ent:GetClass()=="dak_bot" then
					--ent.DakHealth = ent:GetPhysicsObject():GetMass()/20
					ent.DakBurnStacks = 0
					ent.DakHealth = 10
					ent.DakName = "Armor"
					ent.DakMaxHealth = 10
			 		--ent.DakMaxHealth = ent:GetPhysicsObject():GetMass()/20
			 		ent.DakPooled = 0
			 		ent.DakArmor = 10
				end
			end
		end
	end
	
	--example hook add
	--hook.Add( "DakTankDamageCheck", "DakTekTankEditionDamageCheck", function (Damaged,Damager)
	--end )

	function impactexplode(collider, col)
		if collider.IsDakTekFutureTech == nil and col.HitEntity.IsDakTekFutureTech == nil then
			if IsValid(collider.Controller) and IsValid(col.HitEntity.Controller) then
				if not(collider.Controller==col.HitEntity.Controller) then
					if col.HitEntity:GetPhysicsObject():IsMotionEnabled() then
						if hook.Run("DakTankDamageCheck", col.HitEntity, collider.Controller.DakOwner, collider.Controller) ~= false then
							local Damage = ((col.OurOldVelocity-col.TheirOldVelocity):Length()/200)*(collider.DakMaxHealth/col.HitEntity.DakMaxHealth)
							col.HitEntity.DakHealth = col.HitEntity.DakHealth - Damage*25
							collider:EmitSound( "physics/metal/metal_large_debris2.wav" )
							local effectdata = EffectData()
							effectdata:SetOrigin(col.HitPos)
							effectdata:SetEntity(collider)
							effectdata:SetAttachment(1)
							effectdata:SetMagnitude(.5)
							effectdata:SetScale(Damage/10)
							util.Effect("dakshellbounce", effectdata)
						end
					end
				end
			end
		end
	end

	hook.Add( "OnEntityCreated", "AddCollisionBoomFunction", function( ent )
		ent:AddCallback( "PhysicsCollide", impactexplode )
	end )

	hook.Add( "Think", "DakTankShellTableFunction", function()
		if CurTime()-0.1 >= DakTankLastShellThink then
			DakTankLastShellThink = CurTime()
			local ShellList = DakTankShellList
			local RemoveList = {}

			for i = 1, #ShellList do
			ShellList[i].LifeTime = ShellList[i].LifeTime + 0.1
			--ShellList[i].Gravity = physenv.GetGravity()*ShellList[i].LifeTime
			
			local trace = {}
				if ShellList[i].IsGuided then
					local indicatortrace = {}
						if not(ShellList[i].Indicator) then
							indicatortrace.start = ShellList[i].Ang:Forward()*-10000
							indicatortrace.endpos = ShellList[i].Ang:Forward()*10000
						else
							if ShellList[i].Indicator:IsPlayer() then 
								indicatortrace.start = ShellList[i].Indicator:GetShootPos()
								indicatortrace.endpos = ShellList[i].Indicator:GetShootPos()+ShellList[i].Indicator:GetAimVector()*1000000
							else
								indicatortrace.start = ShellList[i].Indicator:GetPos()
								indicatortrace.endpos = ShellList[i].Indicator:GetPos() + ShellList[i].Indicator:GetForward()*1000000
							end
						end
						indicatortrace.filter = ShellList[i].Filter
					local indicator = util.TraceLine(indicatortrace)
					if not(ShellList[i].SimPos) then
						ShellList[i].SimPos = ShellList[i].Pos
					end

					local _, RotatedAngle =	WorldToLocal( Vector(0,0,0), (indicator.HitPos-ShellList[i].SimPos):GetNormalized():Angle(), ShellList[i].SimPos, ShellList[i].Ang )
					local Pitch = math.Clamp(RotatedAngle.p,-10,10)
					local Yaw = math.Clamp(RotatedAngle.y,-10,10)
					local Roll = math.Clamp(RotatedAngle.r,-10,10)
					local _, FlightAngle = LocalToWorld( ShellList[i].SimPos, Angle(Pitch,Yaw,Roll), Vector(0,0,0), Angle(0,0,0) )
					ShellList[i].Ang = ShellList[i].Ang + FlightAngle
					ShellList[i].SimPos = ShellList[i].SimPos + (ShellList[i].DakVelocity * ShellList[i].Ang:Forward()*0.1)

					trace.start = ShellList[i].SimPos + (ShellList[i].DakVelocity * ShellList[i].Ang:Forward()*-0.1)
					trace.endpos = ShellList[i].SimPos + (ShellList[i].DakVelocity * ShellList[i].Ang:Forward()*0.1)
				else
					local DragForce = 0.0245 * ((ShellList[i].DakVelocity*0.0254)*(ShellList[i].DakVelocity*0.0254)) * (math.pi * ((ShellList[i].DakCaliber/2000)*(ShellList[i].DakCaliber/2000)))
					if ShellList[i].DakShellType == "HVAP" then
						DragForce = 0.0245 * ((ShellList[i].DakVelocity*0.0254)*(ShellList[i].DakVelocity*0.0254)) * (math.pi * ((ShellList[i].DakCaliber/1000)*(ShellList[i].DakCaliber/1000)))
					end
					if ShellList[i].DakShellType == "APFSDS" then
						DragForce = 0.085 * ((ShellList[i].DakVelocity*0.0254)*(ShellList[i].DakVelocity*0.0254)) * (math.pi * ((ShellList[i].DakCaliber/1000)*(ShellList[i].DakCaliber/1000)))
					end
					if not(ShellList[i].DakShellType == "HEAT" or ShellList[i].DakShellType == "HEATFS" or ShellList[i].DakShellType == "ATGM" or ShellList[i].DakShellType == "HESH") then
						local PenLoss = ShellList[i].DakBasePenetration*((((DragForce/(ShellList[i].DakMass/2))*0.1)*39.37)/ShellList[i].DakBaseVelocity)
						ShellList[i].DakPenetration = ShellList[i].DakPenetration - PenLoss
					end
					ShellList[i].DakVelocity = ShellList[i].DakVelocity - (((DragForce/(ShellList[i].DakMass/2))*0.1)*39.37)
					trace.start = ShellList[i].Pos + (ShellList[i].DakVelocity * ShellList[i].Ang:Forward() * (ShellList[i].LifeTime-0.1)) - (-physenv.GetGravity()*((ShellList[i].LifeTime-0.1)^2)/2)
					trace.endpos = ShellList[i].Pos + (ShellList[i].DakVelocity * ShellList[i].Ang:Forward() * ShellList[i].LifeTime) - (-physenv.GetGravity()*(ShellList[i].LifeTime^2)/2)
				end
				trace.filter = ShellList[i].Filter
				trace.mins = Vector(-ShellList[i].DakCaliber*0.02,-ShellList[i].DakCaliber*0.02,-ShellList[i].DakCaliber*0.02)
				trace.maxs = Vector(ShellList[i].DakCaliber*0.02,ShellList[i].DakCaliber*0.02,ShellList[i].DakCaliber*0.02)
			local ShellTrace = util.TraceHull( trace )

			local effectdata = EffectData()
			effectdata:SetStart(ShellTrace.StartPos)
			effectdata:SetOrigin(ShellTrace.HitPos)
			effectdata:SetScale((ShellList[i].DakCaliber*0.0393701))
			util.Effect(ShellList[i].DakTrail, effectdata, true, true)

			if ShellTrace.Hit then
				if ShellList[i].IsGuided then
					DTShellHit(ShellTrace.StartPos,ShellList[i].SimPos + (ShellList[i].DakVelocity * ShellList[i].Ang:Forward()*0.1),ShellTrace.Entity,ShellList[i],ShellTrace.HitNormal)
				else
					DTShellHit(ShellTrace.StartPos,ShellList[i].Pos + (ShellList[i].DakVelocity * ShellList[i].Ang:Forward() * ShellList[i].LifeTime) - (-physenv.GetGravity()*(ShellList[i].LifeTime^2)/2),ShellTrace.Entity,ShellList[i],ShellTrace.HitNormal)
				end
			end

			if ShellList[i].DieTime then
				if ShellList[i].DieTime<CurTime()then
					RemoveList[#RemoveList+1] = i
				end
			end

			if ShellList[i].RemoveNow == 1 then
				RemoveList[#RemoveList+1] = i
			end

			--ShellList[i].Pos = ShellList[i].Pos + (ShellList[i].Ang:Forward()*ShellList[i].DakVelocity*0.1) + (ShellList[i].Gravity*0.1)
		end
		
		if #RemoveList > 0 then
			for i = 1, #RemoveList do
				table.remove( ShellList, RemoveList[i] )
			end
		end

	end
	end )

end
